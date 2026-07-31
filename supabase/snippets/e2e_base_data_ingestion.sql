-- P0A base-data ingestion verification. Run against a rebuilt local database.

BEGIN;

DO $$
DECLARE
  v_source_id      UUID;
  v_first_result   JSONB;
  v_replay_result  JSONB;
  v_invalid_result JSONB;
  v_country_count  BIGINT;
  v_city_count     BIGINT;
  v_airport_count  BIGINT;
BEGIN
  INSERT INTO admin.data_sources (
    code,
    name,
    source_type,
    environment_scope,
    production_allowed,
    seo_allowed,
    derived_data_allowed
  )
  VALUES (
    'p0a_ingestion_e2e',
    'P0A ingestion E2E',
    'development_fixture',
    'development',
    FALSE,
    FALSE,
    FALSE
  )
  RETURNING id INTO v_source_id;

  v_first_result := private.publish_base_data_batch(
    'p0a_ingestion_e2e',
    'p0a-valid-idempotency',
    repeat('a', 64),
    'base-data.v1',
    NULL,
    '{
      "countries": [{"iso2":"ZZ","iso3":"ZZZ","name":"Unknown Safe Country"}],
      "cities": [{"sourceId":"city-unknown","name":"Unknown Safe City","countryIso2":"ZZ","latitude":null,"longitude":null}],
      "airports": [{"sourceId":"airport-unknown","name":"Unknown Safe Airport","iata":null,"icao":null,"citySourceId":"city-unknown","countryIso2":"ZZ","latitude":null,"longitude":null,"type":"small_airport"}]
    }'::JSONB
  );

  IF v_first_result ->> 'status' <> 'published' THEN
    RAISE EXCEPTION 'Expected published result, got %', v_first_result;
  END IF;

  SELECT count(*) INTO v_country_count
  FROM public.countries
  WHERE source_id = v_source_id;

  SELECT count(*) INTO v_city_count
  FROM public.cities
  WHERE source_id = v_source_id;

  SELECT count(*) INTO v_airport_count
  FROM public.airports
  WHERE source_id = v_source_id;

  IF (v_country_count, v_city_count, v_airport_count) <> (1, 1, 1) THEN
    RAISE EXCEPTION 'Expected one canonical record per type';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.airports
    WHERE source_id = v_source_id
      AND (latitude IS NOT NULL OR longitude IS NOT NULL OR timezone IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'Unknown optional values must remain NULL';
  END IF;

  v_replay_result := private.publish_base_data_batch(
    'p0a_ingestion_e2e',
    'p0a-valid-idempotency',
    repeat('a', 64),
    'base-data.v1',
    NULL,
    '{"countries":[],"cities":[],"airports":[]}'::JSONB
  );

  IF v_replay_result ->> 'errorCode' <> 'ERR_INGESTION_BATCH_DUPLICATE' THEN
    RAISE EXCEPTION 'Expected duplicate result, got %', v_replay_result;
  END IF;

  v_invalid_result := private.publish_base_data_batch(
    'p0a_ingestion_e2e',
    'p0a-invalid-idempotency',
    repeat('b', 64),
    'base-data.v1',
    NULL,
    '{
      "countries": [],
      "cities": [],
      "airports": [{"sourceId":"broken","name":"Broken Airport","countryIso2":"NO","type":"small_airport"}]
    }'::JSONB
  );

  IF v_invalid_result ->> 'errorCode' <> 'ERR_INGESTION_VALIDATION_FAILED' THEN
    RAISE EXCEPTION 'Expected validation failure, got %', v_invalid_result;
  END IF;

  IF (
    SELECT count(*)
    FROM public.airports
    WHERE source_id = v_source_id
  ) <> v_airport_count THEN
    RAISE EXCEPTION 'Invalid batch changed canonical airport data';
  END IF;
END;
$$;

ROLLBACK;
