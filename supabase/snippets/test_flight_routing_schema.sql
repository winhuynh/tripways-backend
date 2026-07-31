-- Purpose: Verify the minimal flight-routing schema against a rebuilt local database.
-- This script rolls back all fixture rows.

BEGIN;

INSERT INTO admin.data_sources (
  id,
  code,
  name,
  source_type,
  environment_scope
)
VALUES
  (
    '00000000-0000-0000-0000-000000000001',
    'fixture',
    'Development Fixture',
    'development_fixture',
    'development'
  );

INSERT INTO public.countries (id, iso2, iso3, name, slug, source_id, source_record_id)
VALUES
  (
    '00000000-0000-0000-0000-000000000002',
    'XZ',
    'XZZ',
    'Synthetic Test Country',
    'synthetic-test-country',
    '00000000-0000-0000-0000-000000000001',
    'country-xz'
  );

INSERT INTO public.cities (id, country_id, name, slug, source_id, source_record_id)
VALUES
  (
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000002',
    'Synthetic Test City',
    'synthetic-test-city',
    '00000000-0000-0000-0000-000000000001',
    'city-xz'
  );

INSERT INTO public.airports (
  id,
  iata,
  icao,
  name,
  slug,
  city_id,
  country_id,
  latitude,
  longitude,
  airport_type,
  status,
  source_id,
  source_record_id
)
VALUES
  (
    '00000000-0000-0000-0000-000000000004',
    'QAA',
    'ZZZ1',
    'Synthetic Origin Airport',
    'synthetic-origin-airport',
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000002',
    10.8188,
    106.652,
    'large_airport',
    'active',
    '00000000-0000-0000-0000-000000000001',
    'airport-qaa'
  ),
  (
    '00000000-0000-0000-0000-000000000005',
    'QAB',
    'ZZZ2',
    'Synthetic Destination Airport',
    'synthetic-destination-airport',
    NULL,
    '00000000-0000-0000-0000-000000000002',
    21.2212,
    105.807,
    'large_airport',
    'active',
    '00000000-0000-0000-0000-000000000001',
    'airport-qab'
  );

INSERT INTO public.airlines (
  id,
  iata,
  icao,
  name,
  slug,
  country_id,
  status,
  source_id,
  source_record_id
)
VALUES
  (
    '00000000-0000-0000-0000-000000000006',
    'Q1',
    'QAZ',
    'Synthetic Test Airline',
    'synthetic-test-airline',
    '00000000-0000-0000-0000-000000000002',
    'active',
    '00000000-0000-0000-0000-000000000001',
    'airline-q1'
  );

INSERT INTO public.flight_routes (
  id,
  origin_airport_id,
  destination_airport_id,
  operating_airline_id,
  status,
  frequency_per_week,
  seasonality,
  confidence_score,
  source_id,
  source_record_id,
  last_verified_at
)
VALUES
  (
    '00000000-0000-0000-0000-000000000007',
    '00000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000006',
    'verified_active',
    35,
    'year_round',
    0.950,
    '00000000-0000-0000-0000-000000000001',
    'route-qaa-qab-q1',
    now()
  );

DO $$
BEGIN
  BEGIN
    INSERT INTO public.flight_routes (
      origin_airport_id,
      destination_airport_id,
      status,
      confidence_score,
      source_id,
      source_record_id,
      last_verified_at
    )
    VALUES (
      '00000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000004',
      'unknown',
      0.500,
      '00000000-0000-0000-0000-000000000001',
      'invalid-self-route',
      now()
    );
    RAISE EXCEPTION 'Expected flight_routes_direction_check to reject a self-route';
  EXCEPTION
    WHEN check_violation THEN NULL;
  END;

  IF has_table_privilege('anon', 'public.flight_routes', 'select') THEN
    RAISE EXCEPTION 'anon must not have SELECT on public.flight_routes';
  END IF;
END;
$$;

ROLLBACK;
