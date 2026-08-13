-- ============================================================================
-- Function: admin.publish_price_estimate_batch
-- Purpose: Atomically replace one source's current short-lived flight-content observations.
-- Responsibilities: Validate rights/TTL, resolve references, publish current rows, and purge old rows.
-- Notes: The legacy function name remains during the compatibility window.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.publish_price_estimate_batch(
  p_source_code       TEXT,
  p_idempotency_key   TEXT,
  p_checksum          TEXT,
  p_provider_version  TEXT,
  p_source_time       TIMESTAMPTZ,
  p_observations      JSONB,
  p_publication_source_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_source               admin.data_sources%ROWTYPE;
  v_batch_id              UUID;
  v_observation           JSONB;
  v_origin_city           UUID;
  v_destination_city      UUID;
  v_origin_airport        UUID;
  v_destination_airport   UUID;
  v_airline               UUID;
  v_found_at              TIMESTAMPTZ;
  v_provider_expires_at   TIMESTAMPTZ;
  v_valid_until           TIMESTAMPTZ;
  v_count                 INTEGER := 0;
  v_rejected              INTEGER := 0;
  v_resolvable_count      INTEGER := 0;
  v_read_publication      JSONB;
BEGIN
  -- STEP 01: Reject malformed or unbounded publication requests.
  IF p_provider_version <> 'flight-content-observations.v1'
    OR p_checksum !~ '^[a-f0-9]{64}$'
    OR char_length(p_idempotency_key) NOT BETWEEN 8 AND 128
    OR jsonb_typeof(p_observations) <> 'array'
    OR jsonb_array_length(p_observations) > 1000
    OR p_publication_source_type NOT IN ('development_fixture', 'staging', 'production')
  THEN
    RETURN jsonb_build_object(
      'status', 'failed',
      'acceptedCount', 0,
      'rejectedCount', 0,
      'errorCode', 'ERR_INGESTION_INVALID_REQUEST'
    );
  END IF;

  -- STEP 02: Require the complete content-publication rights set.
  SELECT source.*
  INTO v_source
  FROM admin.data_sources AS source
  WHERE source.code = p_source_code;

  IF v_source.id IS NULL
    OR v_source.source_type <> 'content_observation'
    OR NOT v_source.storage_allowed
    OR NOT v_source.cache_allowed
    OR NOT v_source.seo_allowed
    OR NOT v_source.production_display_allowed
    OR v_source.max_cache_ttl_seconds IS NULL
    OR v_source.max_cache_ttl_seconds > 604800
    OR (
      v_source.rights_effective_at IS NOT NULL
      AND now() NOT BETWEEN v_source.rights_effective_at AND v_source.rights_expires_at
    )
  THEN
    RETURN jsonb_build_object(
      'status', 'failed',
      'acceptedCount', 0,
      'rejectedCount', jsonb_array_length(p_observations),
      'errorCode', 'ERR_INGESTION_SOURCE_NOT_ALLOWED'
    );
  END IF;

  -- STEP 03: Make retries idempotent without retaining provider content in the receipt.
  SELECT batch.id
  INTO v_batch_id
  FROM admin.raw_import_batches AS batch
  WHERE batch.source_id = v_source.id
    AND (
      batch.checksum = p_checksum
      OR batch.idempotency_key = p_idempotency_key
    )
  LIMIT 1;

  IF v_batch_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'published',
      'acceptedCount', 0,
      'rejectedCount', 0,
      'errorCode', 'ERR_INGESTION_BATCH_DUPLICATE',
      'batchId', v_batch_id
    );
  END IF;

  -- STEP 04: Preserve the current cache when the new batch cannot map any route.
  SELECT count(*)::INTEGER
  INTO v_resolvable_count
  FROM jsonb_array_elements(p_observations) AS item(value)
  JOIN public.airports AS origin_airport
    ON origin_airport.iata = COALESCE(
      NULLIF(item.value->>'originAirportIata', ''),
      item.value->>'originCode'
    )
  JOIN public.airports AS destination_airport
    ON destination_airport.iata = COALESCE(
      NULLIF(item.value->>'destinationAirportIata', ''),
      item.value->>'destinationCode'
    )
  WHERE origin_airport.city_id <> destination_airport.city_id;

  IF v_resolvable_count = 0 THEN
    RETURN jsonb_build_object(
      'status', 'failed',
      'acceptedCount', 0,
      'rejectedCount', jsonb_array_length(p_observations),
      'errorCode', 'ERR_INGESTION_NO_USABLE_PRICES'
    );
  END IF;

  INSERT INTO admin.raw_import_batches (
    source_id,
    provider_version,
    checksum,
    idempotency_key,
    source_time,
    status
  )
  VALUES (
    v_source.id,
    p_provider_version,
    p_checksum,
    p_idempotency_key,
    p_source_time,
    'validated'
  )
  RETURNING id
  INTO v_batch_id;

  -- STEP 05: Replace the current route-price set inside this transaction.
  DELETE FROM public.flight_route_prices AS observation
  WHERE observation.source_id = v_source.id;

  FOR v_observation IN
    SELECT item.value
    FROM jsonb_array_elements(p_observations) AS item(value)
  LOOP
    v_found_at := (v_observation->>'foundAt')::TIMESTAMPTZ;
    v_provider_expires_at := NULLIF(v_observation->>'providerExpiresAt', '')::TIMESTAMPTZ;
    v_valid_until := (v_observation->>'validUntil')::TIMESTAMPTZ;

    IF NULLIF(btrim(v_observation->>'sourceId'), '') IS NULL
      OR v_valid_until <= v_found_at
      OR v_valid_until > v_found_at + interval '7 days'
      OR (v_provider_expires_at IS NOT NULL AND v_valid_until > v_provider_expires_at)
      OR NULLIF(v_observation->>'affiliatePath', '') ~ '^https?://'
    THEN
      RAISE EXCEPTION USING
        ERRCODE = '22023',
        MESSAGE = 'ERR_INGESTION_VALIDATION_FAILED';
    END IF;

    SELECT airport.id, airport.city_id
    INTO v_origin_airport, v_origin_city
    FROM public.airports AS airport
    WHERE airport.iata = COALESCE(NULLIF(v_observation->>'originAirportIata', ''),v_observation->>'originCode');

    SELECT airport.id, airport.city_id
    INTO v_destination_airport, v_destination_city
    FROM public.airports AS airport
    WHERE airport.iata = COALESCE(NULLIF(v_observation->>'destinationAirportIata', ''),v_observation->>'destinationCode');

    SELECT airline.id
    INTO v_airline
    FROM public.airlines AS airline
    WHERE airline.iata = NULLIF(v_observation->>'airlineIata', '');

    IF v_origin_city IS NULL OR v_destination_city IS NULL THEN
      v_rejected := v_rejected + 1;
      CONTINUE;
    END IF;

    INSERT INTO public.flight_route_prices (
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
    VALUES (
      v_origin_city,
      v_destination_city,
      v_origin_airport,
      v_destination_airport,
      v_airline,
      NULLIF(upper(v_observation->>'airlineIata'), ''),
      v_observation->>'observationType',
      v_observation->>'tripType',
      (v_observation->>'direct')::BOOLEAN,
      (v_observation->>'transferCount')::INTEGER,
      (v_observation->>'amount')::NUMERIC,
      NULLIF(v_observation->>'currencyCode', ''),
      v_observation->>'marketCode',
      v_observation->>'locale',
      (v_observation->>'departureDate')::DATE,
      (v_observation->>'returnDate')::DATE,
      (v_observation->>'durationMinutes')::INTEGER,
      v_source.id,
      v_source.provider_code,
      v_source.provider_code,
      v_observation->>'sourceId',
      v_found_at,
      v_provider_expires_at,
      v_valid_until,
      NULLIF(v_observation->>'affiliatePath', ''),
      'published',
      v_batch_id
    );

    v_count := v_count + 1;
  END LOOP;

  -- STEP 06: Publish one complete page and route snapshot in the same transaction.
  PERFORM admin.sync_provider_pseo_pages(p_publication_source_type);
  v_read_publication := public.publish_read_model_version(p_publication_source_type);

  IF v_read_publication #>> '{error,code}' IS NOT NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'ERR_INGESTION_PUBLISH_FAILED';
  END IF;

  -- STEP 07: Keep only bounded receipt metadata after publication.
  UPDATE admin.raw_import_batches AS batch
  SET status = 'published',
      updated_at = now()
  WHERE batch.id = v_batch_id;

  DELETE FROM admin.raw_import_batches AS batch
  WHERE batch.source_id = v_source.id
    AND batch.id <> v_batch_id
    AND batch.received_at < now() - make_interval(days => COALESCE(v_source.retention_days, 7));

  RETURN jsonb_build_object(
    'status', 'published',
    'acceptedCount', v_count,
    'rejectedCount', v_rejected,
    'errorCode', NULL,
    'batchId', v_batch_id,
    'dataVersion', v_read_publication #>> '{data,data_version}'
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.publish_price_estimate_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB,
  TEXT
)
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION admin.publish_price_estimate_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB,
  TEXT
)
TO service_role;
