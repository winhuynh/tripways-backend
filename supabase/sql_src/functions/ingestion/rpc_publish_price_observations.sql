-- ============================================================================
-- Function: admin.rpc_publish_price_observations
-- Purpose: Atomically publish normalized price observations from provider adapter.
-- Responsibilities: Insert prices with 7-day TTL and update cache lease status.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.rpc_publish_price_observations(
  p_origin_iata TEXT,
  p_destination_iata TEXT,
  p_currency_code TEXT,
  p_market_code TEXT,
  p_observations JSONB,
  p_lease_token UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_origin_norm CHAR(3);
  v_dest_norm CHAR(3);
  v_curr_norm VARCHAR(3);
  v_market_norm VARCHAR(2);
  v_source_id UUID;
  v_obs_count INTEGER := 0;
  v_inserted_count INTEGER := 0;
  v_item RECORD;
  v_origin_city_id UUID;
  v_dest_city_id UUID;
  v_origin_airport_id UUID;
  v_dest_airport_id UUID;
  v_airline_id UUID;
  v_obs_at TIMESTAMPTZ;
  v_valid_until TIMESTAMPTZ;
  v_lease_token UUID;
  v_lease_expires_at TIMESTAMPTZ;
  v_lease_status VARCHAR(20);
  v_published_observations JSONB := '[]'::JSONB;
BEGIN
  v_origin_norm := upper(trim(p_origin_iata));
  v_dest_norm := CASE WHEN p_destination_iata IS NOT NULL AND length(trim(p_destination_iata)) > 0 THEN upper(trim(p_destination_iata)) ELSE NULL END;
  v_curr_norm := upper(trim(coalesce(p_currency_code, 'USD')));
  v_market_norm := lower(trim(coalesce(p_market_code, 'us')));

  IF p_lease_token IS NULL THEN
    RETURN jsonb_build_object('published_count', 0, 'status', 'failed', 'error', 'ERR_LEASE_TOKEN_REQUIRED');
  END IF;

  -- 1. Verify data source approval (Finding R8)
  SELECT id INTO v_source_id
  FROM admin.data_sources
  WHERE code = 'travelpayouts'
    AND is_approved = true
  LIMIT 1;

  IF v_source_id IS NULL THEN
    RETURN jsonb_build_object('published_count', 0, 'status', 'failed', 'error', 'ERR_UNAPPROVED_DATA_SOURCE');
  END IF;

  -- 2. Lock lease row and verify token fencing BEFORE writing any prices (Finding R3)
  SELECT lease_token, lease_expires_at, status
  INTO v_lease_token, v_lease_expires_at, v_lease_status
  FROM admin.route_price_cache_leases
  WHERE origin_iata = v_origin_norm
    AND destination_iata IS NOT DISTINCT FROM v_dest_norm
    AND market_code = v_market_norm
    AND currency_code = v_curr_norm
  FOR UPDATE;

  IF v_lease_token IS NULL OR v_lease_token <> p_lease_token THEN
    RETURN jsonb_build_object(
      'published_count', 0,
      'status', 'failed',
      'error', 'ERR_LEASE_LOST'
    );
  END IF;

  -- Count items in payload
  IF p_observations IS NOT NULL AND jsonb_typeof(p_observations) = 'array' THEN
    v_obs_count := jsonb_array_length(p_observations);
  END IF;

  IF v_obs_count = 0 THEN
    -- Update lease to empty with 6-hour cooldown
    UPDATE admin.route_price_cache_leases
    SET status = 'empty',
        last_attempted_at = now(),
        next_allowed_refresh_at = now() + interval '6 hours',
        lease_expires_at = NULL,
        lease_token = NULL,
        updated_at = now()
    WHERE origin_iata = v_origin_norm
      AND destination_iata IS NOT DISTINCT FROM v_dest_norm
      AND market_code = v_market_norm
      AND currency_code = v_curr_norm
      AND lease_token = p_lease_token;

    RETURN jsonb_build_object('published_count', 0, 'status', 'empty', 'observations', '[]'::JSONB);
  END IF;

  -- Iterate and insert observations
  FOR v_item IN
    SELECT
      upper(trim((elem->>'originIata')::TEXT)) AS origin_iata,
      upper(trim((elem->>'destinationIata')::TEXT)) AS destination_iata,
      upper(trim(coalesce(elem->>'providerAirlineIata', '')))::TEXT AS provider_airline,
      (elem->>'observedAmount')::NUMERIC(14,2) AS observed_amount,
      upper(trim(coalesce(elem->>'currencyCode', v_curr_norm)))::TEXT AS currency,
      coalesce((elem->>'direct')::BOOLEAN, true) AS direct,
      (elem->>'transferCount')::INTEGER AS transfer_count,
      (elem->>'durationMinutes')::INTEGER AS duration_minutes,
      (elem->>'departureDate')::DATE AS departure_date,
      (elem->>'returnDate')::DATE AS return_date,
      coalesce((elem->>'observedAt')::TIMESTAMPTZ, (elem->>'foundAt')::TIMESTAMPTZ, now()) AS observed_at,
      (elem->>'validUntil')::TIMESTAMPTZ AS valid_until_raw,
      coalesce(elem->>'affiliatePath', '/search/' || (elem->>'originIata') || (elem->>'destinationIata')) AS affiliate_path
    FROM jsonb_array_elements(p_observations) AS elem
  LOOP
    -- Lookup origin airport & city
    SELECT a.id, a.city_id INTO v_origin_airport_id, v_origin_city_id
    FROM public.airports AS a
    WHERE a.iata = v_item.origin_iata
    LIMIT 1;

    -- Lookup destination airport & city
    SELECT a.id, a.city_id INTO v_dest_airport_id, v_dest_city_id
    FROM public.airports AS a
    WHERE a.iata = v_item.destination_iata
    LIMIT 1;

    -- Skip if origin or destination airport not in base database or origin == dest
    IF v_origin_city_id IS NULL OR v_dest_city_id IS NULL OR v_origin_city_id = v_dest_city_id THEN
      CONTINUE;
    END IF;

    -- Lookup airline if present
    v_airline_id := NULL;
    IF v_item.provider_airline IS NOT NULL AND length(v_item.provider_airline) >= 2 THEN
      SELECT id INTO v_airline_id
      FROM public.airlines
      WHERE iata = v_item.provider_airline
      LIMIT 1;
    END IF;

    v_obs_at := v_item.observed_at;
    v_valid_until := least(
      greatest(coalesce(v_item.valid_until_raw, v_obs_at + interval '7 days'), v_obs_at + interval '1 minute'),
      v_obs_at + interval '7 days'
    );

    -- Insert or update price observation
    INSERT INTO public.flight_route_prices (
      origin_city_id, destination_city_id, origin_airport_id, destination_airport_id,
      canonical_airline_id, provider_airline_iata, observation_type, trip_type,
      direct, transfer_count, observed_amount, currency_code, market_code, locale,
      departure_date, return_date, duration_minutes, source_id, provider_code,
      source_record_id, observed_at, valid_until, affiliate_path, status
    ) VALUES (
      v_origin_city_id, v_dest_city_id, v_origin_airport_id, v_dest_airport_id,
      v_airline_id, NULLIF(v_item.provider_airline, ''), 'cached_fare',
      CASE WHEN v_item.return_date IS NOT NULL THEN 'return' ELSE 'one_way' END,
      v_item.direct, coalesce(v_item.transfer_count, CASE WHEN v_item.direct THEN 0 ELSE 1 END),
      v_item.observed_amount, v_item.currency, v_market_norm, 'en-GB',
      v_item.departure_date, v_item.return_date, v_item.duration_minutes, v_source_id, 'travelpayouts',
      'tp_' || v_item.origin_iata || '_' || v_item.destination_iata || '_' ||
        to_char(coalesce(v_item.departure_date, CURRENT_DATE), 'YYYYMMDD') || '_' ||
        coalesce(to_char(v_item.return_date, 'YYYYMMDD'), 'ow') || '_' ||
        coalesce(v_item.provider_airline, 'none') || '_' ||
        CASE WHEN v_item.direct THEN 'dir' ELSE 'con' END || '_' ||
        v_market_norm || '_' || v_item.currency,
      v_obs_at, v_valid_until, v_item.affiliate_path, 'published'
    )
    ON CONFLICT (source_id, source_record_id)
    DO UPDATE SET
      observed_amount = EXCLUDED.observed_amount,
      currency_code = EXCLUDED.currency_code,
      direct = EXCLUDED.direct,
      transfer_count = EXCLUDED.transfer_count,
      duration_minutes = EXCLUDED.duration_minutes,
      canonical_airline_id = EXCLUDED.canonical_airline_id,
      provider_airline_iata = EXCLUDED.provider_airline_iata,
      trip_type = EXCLUDED.trip_type,
      departure_date = EXCLUDED.departure_date,
      return_date = EXCLUDED.return_date,
      observed_at = EXCLUDED.observed_at,
      valid_until = EXCLUDED.valid_until,
      affiliate_path = EXCLUDED.affiliate_path,
      status = 'published';

    v_inserted_count := v_inserted_count + 1;
  END LOOP;

  -- If all observations were skipped, lease status is empty with cooldown (Finding R6)
  IF v_inserted_count = 0 THEN
    UPDATE admin.route_price_cache_leases
    SET status = 'empty',
        last_attempted_at = now(),
        next_allowed_refresh_at = now() + interval '6 hours',
        lease_expires_at = NULL,
        lease_token = NULL,
        updated_at = now()
    WHERE origin_iata = v_origin_norm
      AND destination_iata IS NOT DISTINCT FROM v_dest_norm
      AND market_code = v_market_norm
      AND currency_code = v_curr_norm
      AND lease_token = p_lease_token;

    RETURN jsonb_build_object(
      'published_count', 0,
      'status', 'empty',
      'origin', v_origin_norm,
      'destination', v_dest_norm,
      'count', 0,
      'observations', '[]'::JSONB
    );
  END IF;

  -- Update lease status to fresh
  UPDATE admin.route_price_cache_leases
  SET status = 'fresh',
      last_succeeded_at = now(),
      next_allowed_refresh_at = now() + interval '24 hours',
      lease_expires_at = NULL,
      lease_token = NULL,
      updated_at = now()
  WHERE origin_iata = v_origin_norm
    AND destination_iata IS NOT DISTINCT FROM v_dest_norm
    AND market_code = v_market_norm
    AND currency_code = v_curr_norm
    AND lease_token = p_lease_token;

  -- Query and return canonical DTO with observation_ref (Finding R6)
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'observation_ref', p.public_reference,
      'observed_amount', p.observed_amount,
      'currency_code', p.currency_code,
      'departure_date', p.departure_date,
      'direct', p.direct,
      'transfer_count', p.transfer_count,
      'duration_minutes', p.duration_minutes,
      'observed_at', p.observed_at,
      'valid_until', p.valid_until
    ) ORDER BY p.observed_amount ASC NULLS LAST
  ), '[]'::JSONB)
  INTO v_published_observations
  FROM public.flight_route_prices AS p
  JOIN public.airports AS oa ON oa.id = p.origin_airport_id AND oa.iata = v_origin_norm
  LEFT JOIN public.airports AS da ON da.id = p.destination_airport_id AND da.iata = v_dest_norm
  WHERE p.status = 'published'
    AND p.valid_until > now()
    AND p.currency_code = v_curr_norm
    AND p.market_code = v_market_norm
    AND (v_dest_norm IS NULL OR da.id IS NOT NULL);

  RETURN jsonb_build_object(
    'published_count', v_inserted_count,
    'status', 'fresh',
    'origin', v_origin_norm,
    'destination', v_dest_norm,
    'count', v_inserted_count,
    'observations', v_published_observations
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.rpc_publish_price_observations(TEXT, TEXT, TEXT, TEXT, JSONB, UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.rpc_publish_price_observations(TEXT, TEXT, TEXT, TEXT, JSONB, UUID) TO service_role;
