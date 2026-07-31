-- ============================================================================
-- Function: private.publish_base_data_batch
-- Purpose: Validate and atomically publish one canonical base-data batch.
-- Responsibilities:
--   - Enforce source eligibility and replay safety.
--   - Preserve raw records and bounded operational evidence.
--   - Publish countries, cities, and airports only after complete validation.
-- Notes:
--   - P0A supports atomic mode only.
--   - Optional provider values remain NULL and never imply production eligibility.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.publish_base_data_batch(
  p_source_code       TEXT,
  p_idempotency_key   TEXT,
  p_checksum          TEXT,
  p_provider_version  TEXT,
  p_source_time       TIMESTAMPTZ,
  p_records           JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  -- Auth and source
  v_source_id       UUID;

  -- Batch and run
  v_batch_id        UUID;
  v_existing_batch  private.raw_import_batches%ROWTYPE;
  v_run_id          UUID;
  v_record_count    INTEGER;
  v_invalid_count   INTEGER;

  -- Publication
  v_country         JSONB;
  v_city            JSONB;
  v_airport         JSONB;
  v_country_id      UUID;
  v_city_id         UUID;
  v_slug            TEXT;
BEGIN
  -- STEP 01: Validate bounded invocation fields and source rights.
  IF p_source_code IS NULL
    OR p_source_code <> btrim(p_source_code)
    OR p_idempotency_key IS NULL
    OR char_length(p_idempotency_key) NOT BETWEEN 8 AND 128
    OR p_checksum !~ '^[a-f0-9]{64}$'
    OR p_provider_version <> 'base-data.v1'
    OR jsonb_typeof(p_records) <> 'object'
    OR jsonb_typeof(p_records -> 'countries') <> 'array'
    OR jsonb_typeof(p_records -> 'cities') <> 'array'
    OR jsonb_typeof(p_records -> 'airports') <> 'array'
  THEN
    RETURN jsonb_build_object(
      'status', 'failed',
      'errorCode', 'ERR_INGESTION_INVALID_REQUEST'
    );
  END IF;

  SELECT source.id
  INTO v_source_id
  FROM admin.data_sources AS source
  WHERE source.code = p_source_code
    AND source.environment_scope = 'development'
    AND source.production_allowed = FALSE
    AND source.seo_allowed = FALSE
    AND source.source_type IN ('base_data', 'development_fixture');

  IF v_source_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'failed',
      'errorCode', 'ERR_INGESTION_SOURCE_NOT_ALLOWED'
    );
  END IF;

  -- STEP 02: Return the stable result for checksum or idempotency replays.
  SELECT batch.*
  INTO v_existing_batch
  FROM private.raw_import_batches AS batch
  WHERE batch.source_id = v_source_id
    AND (
      batch.checksum = p_checksum
      OR batch.idempotency_key = p_idempotency_key
    )
  ORDER BY batch.received_at
  LIMIT 1;

  IF v_existing_batch.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', v_existing_batch.status,
      'batchId', v_existing_batch.id,
      'duplicate', TRUE,
      'errorCode', 'ERR_INGESTION_BATCH_DUPLICATE'
    );
  END IF;

  -- STEP 03: Persist the raw receipt and an atomic publication run.
  INSERT INTO private.raw_import_batches (
    source_id,
    provider_version,
    checksum,
    idempotency_key,
    source_time,
    status
  )
  VALUES (
    v_source_id,
    p_provider_version,
    p_checksum,
    p_idempotency_key,
    p_source_time,
    'received'
  )
  RETURNING id INTO v_batch_id;

  INSERT INTO private.raw_base_data_records (
    batch_id,
    record_type,
    source_key,
    payload
  )
  SELECT
    v_batch_id,
    records.record_type,
    records.source_key,
    records.payload
  FROM (
    SELECT
      'country'::TEXT AS record_type,
      country ->> 'iso2' AS source_key,
      country AS payload
    FROM jsonb_array_elements(p_records -> 'countries') AS country

    UNION ALL

    SELECT
      'city',
      city ->> 'sourceId',
      city
    FROM jsonb_array_elements(p_records -> 'cities') AS city

    UNION ALL

    SELECT
      'airport',
      airport ->> 'sourceId',
      airport
    FROM jsonb_array_elements(p_records -> 'airports') AS airport
  ) AS records;

  GET DIAGNOSTICS v_record_count = ROW_COUNT;

  INSERT INTO admin.ingestion_runs (
    batch_id,
    action,
    mode,
    status
  )
  VALUES (
    v_batch_id,
    'publish',
    'atomic',
    'started'
  )
  RETURNING id INTO v_run_id;

  -- STEP 04: Validate all required fields, coordinates, duplicates, and references.
  SELECT count(*)
  INTO v_invalid_count
  FROM private.raw_base_data_records AS record
  WHERE record.batch_id = v_batch_id
    AND (
      record.source_key IS NULL
      OR record.source_key = ''
      OR (
        record.record_type = 'country'
        AND (
          record.payload ->> 'iso2' !~ '^[A-Z]{2}$'
          OR record.payload ->> 'iso3' !~ '^[A-Z]{3}$'
          OR NULLIF(btrim(record.payload ->> 'name'), '') IS NULL
        )
      )
      OR (
        record.record_type = 'city'
        AND (
          NULLIF(btrim(record.payload ->> 'name'), '') IS NULL
          OR record.payload ->> 'countryIso2' !~ '^[A-Z]{2}$'
          OR ((record.payload -> 'latitude') IS NULL) <> ((record.payload -> 'longitude') IS NULL)
          OR (
            (record.payload -> 'latitude') IS NOT NULL
            AND (
              (record.payload ->> 'latitude')::DOUBLE PRECISION NOT BETWEEN -90 AND 90
              OR (record.payload ->> 'longitude')::DOUBLE PRECISION NOT BETWEEN -180 AND 180
            )
          )
        )
      )
      OR (
        record.record_type = 'airport'
        AND (
          NULLIF(btrim(record.payload ->> 'name'), '') IS NULL
          OR record.payload ->> 'countryIso2' !~ '^[A-Z]{2}$'
          OR NULLIF(btrim(record.payload ->> 'type'), '') IS NULL
          OR ((record.payload -> 'latitude') IS NULL) <> ((record.payload -> 'longitude') IS NULL)
          OR (
            (record.payload -> 'latitude') IS NOT NULL
            AND (
              (record.payload ->> 'latitude')::DOUBLE PRECISION NOT BETWEEN -90 AND 90
              OR (record.payload ->> 'longitude')::DOUBLE PRECISION NOT BETWEEN -180 AND 180
            )
          )
        )
      )
    );

  v_invalid_count := v_invalid_count + (
    SELECT count(*)::INTEGER
    FROM (
      SELECT record_type, source_key
      FROM private.raw_base_data_records
      WHERE batch_id = v_batch_id
      GROUP BY record_type, source_key
      HAVING count(*) > 1
    ) AS duplicates
  );

  v_invalid_count := v_invalid_count + (
    SELECT count(*)::INTEGER
    FROM private.raw_base_data_records AS record
    WHERE record.batch_id = v_batch_id
      AND record.record_type IN ('city', 'airport')
      AND NOT EXISTS (
        SELECT 1
        FROM private.raw_base_data_records AS country
        WHERE country.batch_id = v_batch_id
          AND country.record_type = 'country'
          AND country.payload ->> 'iso2' = record.payload ->> 'countryIso2'
      )
  );

  v_invalid_count := v_invalid_count + (
    SELECT count(*)::INTEGER
    FROM private.raw_base_data_records AS record
    WHERE record.batch_id = v_batch_id
      AND record.record_type = 'airport'
      AND NULLIF(record.payload ->> 'citySourceId', '') IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM private.raw_base_data_records AS city
        WHERE city.batch_id = v_batch_id
          AND city.record_type = 'city'
          AND city.source_key = record.payload ->> 'citySourceId'
      )
  );

  IF v_invalid_count > 0 THEN
    UPDATE private.raw_base_data_records
    SET validation_state = 'invalid'
    WHERE batch_id = v_batch_id;

    UPDATE private.raw_import_batches
    SET
      status = 'rejected',
      updated_at = now()
    WHERE id = v_batch_id;

    UPDATE admin.ingestion_runs
    SET
      rejected_count = v_record_count,
      status = 'failed',
      stable_error_code = 'ERR_INGESTION_VALIDATION_FAILED',
      completed_at = now()
    WHERE id = v_run_id;

    INSERT INTO admin.ingestion_issues (
      run_id,
      issue_code,
      severity
    )
    VALUES (
      v_run_id,
      'ERR_INGESTION_VALIDATION_FAILED',
      'error'
    );

    RETURN jsonb_build_object(
      'status', 'rejected',
      'batchId', v_batch_id,
      'runId', v_run_id,
      'acceptedCount', 0,
      'rejectedCount', v_record_count,
      'errorCode', 'ERR_INGESTION_VALIDATION_FAILED'
    );
  END IF;

  UPDATE private.raw_base_data_records
  SET validation_state = 'valid'
  WHERE batch_id = v_batch_id;

  -- STEP 05: Publish countries, then cities, then airports.
  FOR v_country IN
    SELECT value
    FROM jsonb_array_elements(p_records -> 'countries')
  LOOP
    v_slug := trim(BOTH '-' FROM regexp_replace(lower(v_country ->> 'name'), '[^a-z0-9]+', '-', 'g'));

    INSERT INTO public.countries (
      iso2,
      iso3,
      name,
      slug,
      source_id,
      source_record_id
    )
    VALUES (
      v_country ->> 'iso2',
      v_country ->> 'iso3',
      btrim(v_country ->> 'name'),
      v_slug,
      v_source_id,
      v_country ->> 'iso2'
    )
    ON CONFLICT (source_id, source_record_id)
    DO UPDATE SET
      iso2 = EXCLUDED.iso2,
      iso3 = EXCLUDED.iso3,
      name = EXCLUDED.name,
      slug = EXCLUDED.slug,
      updated_at = now();
  END LOOP;

  FOR v_city IN
    SELECT value
    FROM jsonb_array_elements(p_records -> 'cities')
  LOOP
    SELECT country.id
    INTO v_country_id
    FROM public.countries AS country
    WHERE country.source_id = v_source_id
      AND country.source_record_id = v_city ->> 'countryIso2';

    v_slug := trim(BOTH '-' FROM regexp_replace(lower(v_city ->> 'name'), '[^a-z0-9]+', '-', 'g'));

    INSERT INTO public.cities (
      country_id,
      name,
      slug,
      latitude,
      longitude,
      timezone,
      source_id,
      source_record_id
    )
    VALUES (
      v_country_id,
      btrim(v_city ->> 'name'),
      v_slug,
      (v_city ->> 'latitude')::DOUBLE PRECISION,
      (v_city ->> 'longitude')::DOUBLE PRECISION,
      NULL,
      v_source_id,
      v_city ->> 'sourceId'
    )
    ON CONFLICT (source_id, source_record_id)
    DO UPDATE SET
      country_id = EXCLUDED.country_id,
      name = EXCLUDED.name,
      slug = EXCLUDED.slug,
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude,
      timezone = NULL,
      updated_at = now();
  END LOOP;

  FOR v_airport IN
    SELECT value
    FROM jsonb_array_elements(p_records -> 'airports')
  LOOP
    SELECT country.id
    INTO v_country_id
    FROM public.countries AS country
    WHERE country.source_id = v_source_id
      AND country.source_record_id = v_airport ->> 'countryIso2';

    v_city_id := NULL;
    IF NULLIF(v_airport ->> 'citySourceId', '') IS NOT NULL THEN
      SELECT city.id
      INTO v_city_id
      FROM public.cities AS city
      WHERE city.source_id = v_source_id
        AND city.source_record_id = v_airport ->> 'citySourceId';
    END IF;

    v_slug := trim(
      BOTH '-'
      FROM regexp_replace(
        lower(
          COALESCE(
            NULLIF(v_airport ->> 'iata', ''),
            v_airport ->> 'name'
          )
        ),
        '[^a-z0-9]+',
        '-',
        'g'
      )
    );

    INSERT INTO public.airports (
      iata,
      icao,
      name,
      slug,
      city_id,
      country_id,
      latitude,
      longitude,
      timezone,
      airport_type,
      status,
      source_id,
      source_record_id,
      last_verified_at
    )
    VALUES (
      NULLIF(v_airport ->> 'iata', ''),
      NULLIF(v_airport ->> 'icao', ''),
      btrim(v_airport ->> 'name'),
      v_slug,
      v_city_id,
      v_country_id,
      (v_airport ->> 'latitude')::DOUBLE PRECISION,
      (v_airport ->> 'longitude')::DOUBLE PRECISION,
      NULL,
      v_airport ->> 'type',
      'unknown',
      v_source_id,
      v_airport ->> 'sourceId',
      p_source_time
    )
    ON CONFLICT (source_id, source_record_id)
    DO UPDATE SET
      iata = EXCLUDED.iata,
      icao = EXCLUDED.icao,
      name = EXCLUDED.name,
      slug = EXCLUDED.slug,
      city_id = EXCLUDED.city_id,
      country_id = EXCLUDED.country_id,
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude,
      timezone = NULL,
      airport_type = EXCLUDED.airport_type,
      status = 'unknown',
      last_verified_at = EXCLUDED.last_verified_at,
      updated_at = now();
  END LOOP;

  -- STEP 06: Complete the operational evidence after canonical publication.
  UPDATE private.raw_import_batches
  SET
    status = 'published',
    updated_at = now()
  WHERE id = v_batch_id;

  UPDATE admin.ingestion_runs
  SET
    accepted_count = v_record_count,
    status = 'succeeded',
    completed_at = now()
  WHERE id = v_run_id;

  RETURN jsonb_build_object(
    'status', 'published',
    'batchId', v_batch_id,
    'runId', v_run_id,
    'acceptedCount', v_record_count,
    'rejectedCount', 0,
    'errorCode', NULL
  );
EXCEPTION
  WHEN unique_violation OR check_violation OR foreign_key_violation THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'ERR_INGESTION_PUBLISH_FAILED';
END;
$$;

REVOKE ALL ON FUNCTION private.publish_base_data_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB
) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.publish_base_data_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB
) TO service_role;
