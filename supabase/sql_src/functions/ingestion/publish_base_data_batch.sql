-- ============================================================================
-- Function: admin.publish_base_data_batch
-- Purpose: Validate and atomically publish one canonical base-data batch.
-- Responsibilities:
--   - Enforce source eligibility and replay safety.
--   - Preserve raw records and bounded operational evidence.
--   - Publish countries, cities, and airports only after complete validation.
-- Notes:
--   - P0A supports atomic mode only.
--   - Optional provider values remain NULL and never imply production eligibility.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.publish_base_data_batch(
  p_source_code       TEXT,
  p_idempotency_key   TEXT,
  p_checksum          TEXT,
  p_provider_version  TEXT,
  p_source_time       TIMESTAMPTZ,
  p_records           JSONB,
  p_import_metadata   JSONB DEFAULT NULL
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
  v_existing_batch  admin.raw_import_batches%ROWTYPE;
  v_record_count    INTEGER;
  v_invalid_count   INTEGER;
  v_previous_eligible_count INTEGER;
  v_eligible_count  INTEGER;
  v_deactivation_count INTEGER;
  v_is_production_source BOOLEAN;

  -- Publication
  v_country         JSONB;
  v_city            JSONB;
  v_airport         JSONB;
  v_country_id      UUID;
  v_city_id         UUID;
  v_slug            TEXT;
  v_city_record     JSONB;
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
    OR (p_import_metadata IS NOT NULL AND jsonb_typeof(p_import_metadata) <> 'object')
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
    AND source.source_type IN ('base_data', 'development_fixture');

  IF v_source_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'failed',
      'errorCode', 'ERR_INGESTION_SOURCE_NOT_ALLOWED'
    );
  END IF;

  SELECT source.environment_scope = 'production'
  INTO v_is_production_source
  FROM admin.data_sources AS source
  WHERE source.id = v_source_id;

  IF v_is_production_source AND NOT EXISTS (
    SELECT 1
    FROM admin.data_sources AS source
    WHERE source.id = v_source_id
      AND source.production_allowed
      AND source.storage_allowed
      AND source.production_display_allowed
      AND (source.rights_effective_at IS NULL OR source.rights_effective_at <= now())
      AND (source.rights_expires_at IS NULL OR source.rights_expires_at > now())
  ) THEN
    RETURN jsonb_build_object(
      'status', 'failed',
      'errorCode', 'ERR_INGESTION_SOURCE_NOT_ALLOWED'
    );
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_source_code));

  -- STEP 02: Return the stable result for checksum or idempotency replays.
  SELECT batch.*
  INTO v_existing_batch
  FROM admin.raw_import_batches AS batch
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
  INSERT INTO admin.raw_import_batches (
    source_id,
    provider_version,
    checksum,
    idempotency_key,
    source_time,
    source_url,
    source_etag,
    downloaded_bytes,
    raw_record_count,
    eligible_record_count,
    filtered_record_count,
    invalid_record_count,
    filter_version,
    status
  )
  VALUES (
    v_source_id,
    p_provider_version,
    p_checksum,
    p_idempotency_key,
    p_source_time,
    p_import_metadata ->> 'sourceUrl',
    p_import_metadata ->> 'sourceEtag',
    (p_import_metadata ->> 'downloadedBytes')::INTEGER,
    (p_import_metadata ->> 'rawRecordCount')::INTEGER,
    (p_import_metadata ->> 'eligibleRecordCount')::INTEGER,
    (p_import_metadata ->> 'filteredRecordCount')::INTEGER,
    (p_import_metadata ->> 'invalidRecordCount')::INTEGER,
    p_import_metadata ->> 'filterVersion',
    'received'
  )
  RETURNING id INTO v_batch_id;

  INSERT INTO admin.raw_base_data_records (
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

  -- STEP 04: Hold anomalous production snapshots for review before canonical mutation.
  v_eligible_count := jsonb_array_length(p_records -> 'airports');

  SELECT batch.eligible_record_count
  INTO v_previous_eligible_count
  FROM admin.raw_import_batches AS batch
  WHERE batch.source_id = v_source_id
    AND batch.status = 'published'
    AND batch.id <> v_batch_id
    AND batch.eligible_record_count IS NOT NULL
  ORDER BY batch.received_at DESC
  LIMIT 1;

  SELECT count(*)::INTEGER
  INTO v_deactivation_count
  FROM public.airports AS airport
  WHERE airport.source_id = v_source_id
    AND airport.status = 'active'
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(p_records -> 'airports') AS candidate
      WHERE candidate ->> 'sourceId' = airport.source_record_id
    );

  IF v_is_production_source
    AND v_previous_eligible_count > 0
    AND (
      v_eligible_count < v_previous_eligible_count * 0.95
      OR abs(v_eligible_count - v_previous_eligible_count) > v_previous_eligible_count * 0.15
      OR v_deactivation_count > greatest(1, ceil(v_previous_eligible_count * 0.02))
    )
  THEN
    UPDATE admin.raw_import_batches
    SET status = 'awaiting_review', updated_at = now()
    WHERE id = v_batch_id;

    RETURN jsonb_build_object(
      'status', 'awaiting_review',
      'batchId', v_batch_id,
      'acceptedCount', 0,
      'rejectedCount', v_record_count,
      'errorCode', 'ERR_INGESTION_ANOMALY_REVIEW_REQUIRED'
    );
  END IF;

  -- STEP 05: Validate all required fields, coordinates, duplicates, and references.
  SELECT count(*)
  INTO v_invalid_count
  FROM admin.raw_base_data_records AS record
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
      FROM admin.raw_base_data_records
      WHERE batch_id = v_batch_id
      GROUP BY record_type, source_key
      HAVING count(*) > 1
    ) AS duplicates
  );

  v_invalid_count := v_invalid_count + (
    SELECT count(*)::INTEGER
    FROM admin.raw_base_data_records AS record
    WHERE record.batch_id = v_batch_id
      AND record.record_type IN ('city', 'airport')
      AND NOT EXISTS (
        SELECT 1
        FROM admin.raw_base_data_records AS country
        WHERE country.batch_id = v_batch_id
          AND country.record_type = 'country'
          AND country.payload ->> 'iso2' = record.payload ->> 'countryIso2'
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.countries AS country
        WHERE country.iso2 = record.payload ->> 'countryIso2'
      )
  );

  v_invalid_count := v_invalid_count + (
    SELECT count(*)::INTEGER
    FROM admin.raw_base_data_records AS record
    WHERE record.batch_id = v_batch_id
      AND record.record_type = 'airport'
      AND NULLIF(record.payload ->> 'citySourceId', '') IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM admin.raw_base_data_records AS city
        WHERE city.batch_id = v_batch_id
          AND city.record_type = 'city'
          AND city.source_key = record.payload ->> 'citySourceId'
      )
  );

  IF v_invalid_count > 0 THEN
    UPDATE admin.raw_base_data_records
    SET validation_state = 'invalid'
    WHERE batch_id = v_batch_id;

    UPDATE admin.raw_import_batches
    SET
      status = 'rejected',
      updated_at = now()
    WHERE id = v_batch_id;

    RETURN jsonb_build_object(
      'status', 'rejected',
      'batchId', v_batch_id,
      'acceptedCount', 0,
      'rejectedCount', v_record_count,
      'errorCode', 'ERR_INGESTION_VALIDATION_FAILED'
    );
  END IF;

  UPDATE admin.raw_base_data_records
  SET validation_state = 'valid'
  WHERE batch_id = v_batch_id;

  -- STEP 06: Publish countries, then cities, then airports.
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
      region,
      subregion,
      source_id,
      source_record_id
    )
    VALUES (
      v_country ->> 'iso2',
      v_country ->> 'iso3',
      btrim(v_country ->> 'name'),
      v_slug,
      NULLIF(btrim(v_country ->> 'region'), ''),
      NULLIF(btrim(v_country ->> 'subregion'), ''),
      v_source_id,
      v_country ->> 'iso2'
    )
    ON CONFLICT (iso2) DO NOTHING;

    UPDATE public.countries AS country
    SET
      iso3 = v_country ->> 'iso3',
      name = btrim(v_country ->> 'name'),
      slug = v_slug,
      region = COALESCE(NULLIF(btrim(v_country ->> 'region'), ''), country.region),
      subregion = COALESCE(NULLIF(btrim(v_country ->> 'subregion'), ''), country.subregion),
      updated_at = now()
    WHERE country.source_id = v_source_id
      AND country.source_record_id = v_country ->> 'iso2';
  END LOOP;

  FOR v_city IN
    SELECT value
    FROM jsonb_array_elements(p_records -> 'cities')
  LOOP
    SELECT country.id
    INTO v_country_id
    FROM public.countries AS country
    WHERE country.iso2 = v_city ->> 'countryIso2'
    ORDER BY (country.source_id = v_source_id) DESC
    LIMIT 1;

    v_slug := trim(BOTH '-' FROM regexp_replace(lower(v_city ->> 'name'), '[^a-z0-9]+', '-', 'g'));

    INSERT INTO public.cities (
      country_id,
      name,
      slug,
      iata_code,
      currency_code,
      primary_language,
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
      NULLIF(btrim(v_city ->> 'iataCode'), ''),
      NULLIF(btrim(v_city ->> 'currencyCode'), ''),
      NULLIF(btrim(v_city ->> 'primaryLanguage'), ''),
      (v_city ->> 'latitude')::DOUBLE PRECISION,
      (v_city ->> 'longitude')::DOUBLE PRECISION,
      NULLIF(btrim(v_city ->> 'timezone'), ''),
      v_source_id,
      v_city ->> 'sourceId'
    )
    ON CONFLICT (country_id, slug) DO NOTHING;

    UPDATE public.cities AS city
    SET
      country_id = v_country_id,
      name = btrim(v_city ->> 'name'),
      slug = v_slug,
      iata_code = COALESCE(NULLIF(btrim(v_city ->> 'iataCode'), ''), city.iata_code),
      currency_code = COALESCE(NULLIF(btrim(v_city ->> 'currencyCode'), ''), city.currency_code),
      primary_language = COALESCE(NULLIF(btrim(v_city ->> 'primaryLanguage'), ''), city.primary_language),
      latitude = COALESCE((v_city ->> 'latitude')::DOUBLE PRECISION, city.latitude),
      longitude = COALESCE((v_city ->> 'longitude')::DOUBLE PRECISION, city.longitude),
      timezone = COALESCE(NULLIF(btrim(v_city ->> 'timezone'), ''), city.timezone),
      updated_at = now()
    WHERE city.source_id = v_source_id
      AND city.source_record_id = v_city ->> 'sourceId';
  END LOOP;

  FOR v_airport IN
    SELECT value
    FROM jsonb_array_elements(p_records -> 'airports')
  LOOP
    SELECT country.id
    INTO v_country_id
    FROM public.countries AS country
    WHERE country.iso2 = v_airport ->> 'countryIso2'
    ORDER BY (country.source_id = v_source_id) DESC
    LIMIT 1;

    v_city_id := NULL;
    IF NULLIF(v_airport ->> 'citySourceId', '') IS NOT NULL THEN
      SELECT city.id
      INTO v_city_id
      FROM public.cities AS city
      WHERE city.source_id = v_source_id
        AND city.source_record_id = v_airport ->> 'citySourceId';

      IF v_city_id IS NULL THEN
        SELECT record.payload
        INTO v_city_record
        FROM admin.raw_base_data_records AS record
        WHERE record.batch_id = v_batch_id
          AND record.record_type = 'city'
          AND record.source_key = v_airport ->> 'citySourceId';

        IF v_city_record IS NOT NULL THEN
          v_slug := trim(
            BOTH '-'
            FROM regexp_replace(lower(v_city_record ->> 'name'), '[^a-z0-9]+', '-', 'g')
          );

          SELECT city.id
          INTO v_city_id
          FROM public.cities AS city
          JOIN public.countries AS country
            ON country.id = city.country_id
          WHERE country.iso2 = v_city_record ->> 'countryIso2'
            AND city.slug = v_slug
          LIMIT 1;
        END IF;
      END IF;
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
      image_path,
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
      NULLIF(btrim(v_airport ->> 'imagePath'), ''),
      v_city_id,
      v_country_id,
      (v_airport ->> 'latitude')::DOUBLE PRECISION,
      (v_airport ->> 'longitude')::DOUBLE PRECISION,
      NULLIF(btrim(v_airport ->> 'timezone'), ''),
      v_airport ->> 'type',
      CASE WHEN v_is_production_source THEN 'active' ELSE 'unknown' END,
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
      image_path = COALESCE(EXCLUDED.image_path, airports.image_path),
      city_id = EXCLUDED.city_id,
      country_id = EXCLUDED.country_id,
      latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude,
      timezone = COALESCE(EXCLUDED.timezone, airports.timezone),
      airport_type = EXCLUDED.airport_type,
      status = CASE WHEN v_is_production_source THEN 'active' ELSE 'unknown' END,
      last_verified_at = EXCLUDED.last_verified_at,
      updated_at = now();
  END LOOP;

  IF v_is_production_source THEN
    UPDATE public.airports AS airport
    SET
      status = 'inactive',
      updated_at = now()
    WHERE airport.source_id = v_source_id
      AND airport.status = 'active'
      AND NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_records -> 'airports') AS candidate
        WHERE candidate ->> 'sourceId' = airport.source_record_id
      );
  END IF;

  -- STEP 07: Complete the operational evidence after canonical publication.
  UPDATE admin.raw_import_batches
  SET
    status = 'published',
    updated_at = now()
  WHERE id = v_batch_id;

  -- STEP 08: Bound receipt retention independently from read-model publication.
  DELETE FROM admin.raw_import_batches AS batch
  USING admin.data_sources AS source
  WHERE batch.source_id = source.id
    AND source.id = v_source_id
    AND batch.id <> v_batch_id
    AND batch.received_at < now() - make_interval(days => COALESCE(source.retention_days, 30));

  RETURN jsonb_build_object(
    'status', 'published',
    'batchId', v_batch_id,
    'acceptedCount', v_record_count,
    'rejectedCount', 0,
    'errorCode', NULL,
    'dataVersion', NULL
  );
EXCEPTION
  WHEN unique_violation OR check_violation OR foreign_key_violation THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'ERR_INGESTION_PUBLISH_FAILED';
END;
$$;

REVOKE ALL ON FUNCTION admin.publish_base_data_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB,
  JSONB
) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION admin.publish_base_data_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB,
  JSONB
) TO service_role;
