-- OurAirports publication and anomaly-gate verification. Runs inside a rollback transaction.

BEGIN;

DO $$
DECLARE
  v_first_result   JSONB;
  v_second_result  JSONB;
BEGIN
  SELECT public.rpc_publish_base_data_batch(
    'ourairports',
    'ourairports-e2e-001',
    repeat('a', 64),
    'base-data.v1',
    '2026-08-11T00:00:00Z',
    jsonb_build_object(
      'countries', '[]'::JSONB,
      'cities', jsonb_build_array(
        jsonb_build_object(
          'sourceId', 'ourairports-city:gb:gb-eng:e2e-city',
          'name', 'OurAirports E2E City',
          'countryIso2', 'GB',
          'latitude', NULL,
          'longitude', NULL
        )
      ),
      'airports', jsonb_build_array(
        jsonb_build_object(
          'sourceId', '990001',
          'name', 'OurAirports E2E One',
          'iata', 'QAZ',
          'icao', NULL,
          'citySourceId', 'ourairports-city:gb:gb-eng:e2e-city',
          'countryIso2', 'GB',
          'latitude', 51.0,
          'longitude', 0.0,
          'type', 'medium_airport'
        ),
        jsonb_build_object(
          'sourceId', '990002',
          'name', 'OurAirports E2E Two',
          'iata', 'QAY',
          'icao', NULL,
          'citySourceId', NULL,
          'countryIso2', 'GB',
          'latitude', 52.0,
          'longitude', 1.0,
          'type', 'large_airport'
        )
      )
    ),
    jsonb_build_object(
      'sourceUrl', 'https://example.test/airports.csv',
      'sourceEtag', '"e2e-1"',
      'downloadedBytes', 100,
      'rawRecordCount', 10,
      'eligibleRecordCount', 2,
      'filteredRecordCount', 8,
      'invalidRecordCount', 0,
      'filterVersion', 'ourairports-commercial.v1'
    )
  )
  INTO v_first_result;

  IF v_first_result ->> 'status' <> 'published' THEN
    RAISE EXCEPTION 'first OurAirports batch was not published: %', v_first_result;
  END IF;

  IF (
    SELECT count(*)
    FROM public.airports AS airport
    JOIN admin.data_sources AS source ON source.id = airport.source_id
    WHERE source.code = 'ourairports'
      AND airport.status = 'active'
      AND airport.iata IN ('QAZ', 'QAY')
  ) <> 2 THEN
    RAISE EXCEPTION 'published OurAirports airports were not active';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.cities AS city
    JOIN public.countries AS country ON country.id = city.country_id
    WHERE city.source_record_id = 'ourairports-city:gb:gb-eng:e2e-city'
      AND country.iso2 = 'GB'
  ) THEN
    RAISE EXCEPTION 'OurAirports city did not resolve an existing cross-source country';
  END IF;

  SELECT public.rpc_publish_base_data_batch(
    'ourairports',
    'ourairports-e2e-002',
    repeat('b', 64),
    'base-data.v1',
    '2026-08-12T00:00:00Z',
    jsonb_build_object(
      'countries', '[]'::JSONB,
      'cities', '[]'::JSONB,
      'airports', jsonb_build_array(
        jsonb_build_object(
          'sourceId', '990001',
          'name', 'OurAirports E2E One',
          'iata', 'QAZ',
          'icao', NULL,
          'citySourceId', NULL,
          'countryIso2', 'GB',
          'latitude', 51.0,
          'longitude', 0.0,
          'type', 'medium_airport'
        )
      )
    ),
    jsonb_build_object(
      'sourceUrl', 'https://example.test/airports.csv',
      'sourceEtag', '"e2e-2"',
      'downloadedBytes', 90,
      'rawRecordCount', 9,
      'eligibleRecordCount', 1,
      'filteredRecordCount', 8,
      'invalidRecordCount', 0,
      'filterVersion', 'ourairports-commercial.v1'
    )
  )
  INTO v_second_result;

  IF v_second_result ->> 'errorCode' <> 'ERR_INGESTION_ANOMALY_REVIEW_REQUIRED' THEN
    RAISE EXCEPTION 'anomalous OurAirports batch was not held: %', v_second_result;
  END IF;

  IF (
    SELECT status
    FROM public.airports
    WHERE iata = 'QAY'
  ) <> 'active' THEN
    RAISE EXCEPTION 'anomaly gate mutated the previously published dataset';
  END IF;
END;
$$;

ROLLBACK;
