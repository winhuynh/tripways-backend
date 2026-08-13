-- ============================================================================
-- Function: admin.publish_flight_route_cache_scope
-- Purpose: Atomically replace one demanded Travelpayouts cache scope.
-- Responsibilities: Validate lease/rights, resolve canonical entities, and preserve other origins.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.publish_flight_route_cache_scope(
  p_lease_token      TEXT,
  p_source_code      TEXT,
  p_origin_iata      TEXT,
  p_destination_iata TEXT,
  p_market_code      TEXT,
  p_currency_code    TEXT,
  p_locale           TEXT,
  p_observations     JSONB,
  p_publication_source_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_cache            admin.flight_route_cache_states%ROWTYPE;
  v_source           admin.data_sources%ROWTYPE;
  v_resolvable_count INTEGER;
  v_inserted_count   INTEGER := 0;
  v_valid_until      TIMESTAMPTZ;
BEGIN
  -- STEP 01: Lock and validate the exact refresh lease and canonical scope.
  SELECT cache.*
  INTO v_cache
  FROM admin.flight_route_cache_states AS cache
  WHERE cache.lease_token = p_lease_token
  FOR UPDATE;

  IF v_cache.cache_key IS NULL
    OR v_cache.lease_expires_at <= now()
    OR v_cache.origin_iata <> p_origin_iata
    OR v_cache.destination_iata IS DISTINCT FROM p_destination_iata
    OR v_cache.market_code <> p_market_code
    OR v_cache.currency_code <> p_currency_code
    OR v_cache.locale <> p_locale
    OR jsonb_typeof(p_observations) <> 'array'
    OR jsonb_array_length(p_observations) > 1000
    OR p_publication_source_type NOT IN ('development_fixture', 'staging', 'production')
  THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST';
  END IF;

  SELECT source.*
  INTO v_source
  FROM admin.data_sources AS source
  WHERE source.code = p_source_code;

  IF v_source.id IS NULL
    OR v_source.source_type <> 'content_observation'
    OR NOT v_source.storage_allowed
    OR NOT v_source.cache_allowed
    OR NOT v_source.production_display_allowed
    OR v_source.max_cache_ttl_seconds IS NULL
    OR v_source.max_cache_ttl_seconds > 604800
  THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'ERR_INGESTION_SOURCE_NOT_ALLOWED';
  END IF;

  -- STEP 02: Resolve the whole candidate before replacing any current rows.
  SELECT count(*)::INTEGER, min((item.value->>'validUntil')::TIMESTAMPTZ)
  INTO v_resolvable_count, v_valid_until
  FROM jsonb_array_elements(p_observations) AS item(value)
  JOIN public.airports AS origin_airport
    ON origin_airport.iata = item.value->>'originAirportIata'
  JOIN public.airports AS destination_airport
    ON destination_airport.iata = item.value->>'destinationAirportIata'
  WHERE origin_airport.city_id <> destination_airport.city_id
    AND (item.value->>'originCode') = p_origin_iata
    AND (
      p_destination_iata IS NULL
      OR (item.value->>'destinationCode') = p_destination_iata
    )
    AND (item.value->>'marketCode') = p_market_code
    AND (item.value->>'currencyCode') = p_currency_code
    AND (item.value->>'locale') = p_locale
    AND (item.value->>'validUntil')::TIMESTAMPTZ > now()
    AND (item.value->>'validUntil')::TIMESTAMPTZ
      <= (item.value->>'foundAt')::TIMESTAMPTZ + INTERVAL '7 days';

  IF jsonb_array_length(p_observations) > 0 AND v_resolvable_count = 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_INGESTION_NO_USABLE_PRICES';
  END IF;

  -- STEP 03: Replace only this cache key; never touch another demanded origin.
  IF v_resolvable_count > 0 THEN
    DELETE FROM public.flight_route_prices AS price
    WHERE price.cache_key = v_cache.cache_key
      AND price.source_id = v_source.id
      AND price.request_origin_iata = p_origin_iata
      AND price.market_code = p_market_code
      AND price.currency_code = p_currency_code
      AND price.locale = p_locale;

    INSERT INTO public.flight_route_prices (
      cache_key,
      request_origin_iata,
      origin_city_id,
      destination_city_id,
      origin_airport_id,
      destination_airport_id,
      canonical_airline_id,
      provider_airline_iata,
      observation_type,
      trip_type,
      direct,
      transfer_count,
      observed_amount,
      currency_code,
      market_code,
      locale,
      departure_date,
      return_date,
      duration_minutes,
      source_id,
      data_source,
      provider_code,
      source_record_id,
      observed_at,
      provider_expires_at,
      valid_until,
      affiliate_path,
      status,
      data_version
    )
    SELECT
      v_cache.cache_key,
      p_origin_iata,
      origin_airport.city_id,
      destination_airport.city_id,
      origin_airport.id,
      destination_airport.id,
      airline.id,
      NULLIF(item.value->>'airlineIata', ''),
      item.value->>'observationType',
      item.value->>'tripType',
      (item.value->>'direct')::BOOLEAN,
      (item.value->>'transferCount')::INTEGER,
      (item.value->>'amount')::NUMERIC,
      item.value->>'currencyCode',
      item.value->>'marketCode',
      item.value->>'locale',
      NULLIF(item.value->>'departureDate', '')::DATE,
      NULLIF(item.value->>'returnDate', '')::DATE,
      NULLIF(item.value->>'durationMinutes', '')::INTEGER,
      v_source.id,
      v_source.provider_code,
      v_source.provider_code,
      item.value->>'sourceId',
      (item.value->>'foundAt')::TIMESTAMPTZ,
      NULLIF(item.value->>'providerExpiresAt', '')::TIMESTAMPTZ,
      (item.value->>'validUntil')::TIMESTAMPTZ,
      NULLIF(item.value->>'affiliatePath', ''),
      'published',
      gen_random_uuid()
    FROM jsonb_array_elements(p_observations) AS item(value)
    JOIN public.airports AS origin_airport
      ON origin_airport.iata = item.value->>'originAirportIata'
    JOIN public.airports AS destination_airport
      ON destination_airport.iata = item.value->>'destinationAirportIata'
    LEFT JOIN public.airlines AS airline
      ON airline.iata = NULLIF(item.value->>'airlineIata', '')
    WHERE origin_airport.city_id <> destination_airport.city_id
      AND (item.value->>'originCode') = p_origin_iata
      AND (
        p_destination_iata IS NULL
        OR (item.value->>'destinationCode') = p_destination_iata
      );

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
  END IF;

  -- STEP 04: Finalize freshness or a bounded empty-result cooldown.
  UPDATE admin.flight_route_cache_states AS cache
  SET
    status = CASE WHEN v_inserted_count > 0 THEN 'fresh' ELSE 'empty' END,
    lease_token = NULL,
    lease_expires_at = NULL,
    next_refresh_at = CASE
      WHEN v_inserted_count > 0 THEN COALESCE(v_valid_until, now() + INTERVAL '7 days')
      ELSE now() + INTERVAL '24 hours'
    END,
    last_succeeded_at = now(),
    refreshed_at = now(),
    valid_until = v_valid_until,
    observation_count = v_inserted_count,
    consecutive_failures = 0,
    failure_code = NULL,
    updated_at = now()
  WHERE cache.cache_key = v_cache.cache_key;

  IF v_inserted_count > 0 THEN
    PERFORM admin.sync_provider_pseo_pages(p_publication_source_type);
    PERFORM public.publish_read_model_version(p_publication_source_type);
  END IF;

  RETURN public.rpc_get_flight_route_cache(jsonb_build_object(
    'origin', p_origin_iata,
    'destination', p_destination_iata,
    'market', p_market_code,
    'currency', p_currency_code,
    'locale', p_locale
  ));
END;
$$;

REVOKE ALL ON FUNCTION admin.publish_flight_route_cache_scope(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.publish_flight_route_cache_scope(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
)
TO service_role;
