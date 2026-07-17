\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(
  p_condition BOOLEAN,
  p_message TEXT
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT COALESCE(p_condition, FALSE) THEN
    RAISE EXCEPTION 'ASSERTION FAILED: %', p_message;
  END IF;
END;
$$;

SELECT pg_temp.test_assert(
  (SELECT count(*) FROM public.airports) >= 5,
  'requires five airports'
);

SELECT pg_temp.test_assert(
  (SELECT count(*) FROM public.flight_routes) >= 6,
  'requires direct, connection, rejected, and inactive route edges'
);

SELECT pg_temp.test_assert(
  (SELECT count(*) FROM public.flight_services) >= 7,
  'requires direct, valid connection, short connection, and inactive services'
);

SELECT pg_temp.test_assert(
  EXISTS (
    SELECT 1
    FROM admin.data_sources
    WHERE code = 'route_discovery_fixture'
      AND environment_scope = 'development'
      AND production_allowed = FALSE
      AND seo_allowed = FALSE
      AND derived_data_allowed = FALSE
  ),
  'fixture source must never be production or SEO eligible'
);

SELECT pg_temp.test_assert(
  EXISTS (
    SELECT 1
    FROM public.flight_routes route
    JOIN public.airports origin ON origin.id = route.origin_airport_id
    JOIN public.airports destination ON destination.id = route.destination_airport_id
    WHERE origin.iata = 'SGN'
      AND destination.iata = 'LHR'
      AND route.status = 'verified_active'
  ),
  'requires a direct SGN to LHR route'
);

SELECT pg_temp.test_assert(
  EXISTS (
    SELECT 1
    FROM public.flight_routes first_leg
    JOIN public.airports origin ON origin.id = first_leg.origin_airport_id
    JOIN public.airports connection ON connection.id = first_leg.destination_airport_id
    JOIN public.flight_routes second_leg
      ON second_leg.origin_airport_id = connection.id
    JOIN public.airports destination ON destination.id = second_leg.destination_airport_id
    WHERE origin.iata = 'SGN'
      AND connection.iata = 'SIN'
      AND destination.iata = 'LHR'
      AND first_leg.status = 'verified_active'
      AND second_leg.status = 'verified_active'
  ),
  'requires a valid SGN to SIN to LHR path'
);

ROLLBACK;
