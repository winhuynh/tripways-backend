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

SELECT public.refresh_route_options();

SELECT pg_temp.test_assert(
  public.calculate_layover_minutes(TIME '07:00', 2::SMALLINT, TIME '10:00') = 180,
  'layover calculation normalizes multi-day arrival offsets'
);

SELECT pg_temp.test_assert(
  (
    SELECT count(*) = 2
    FROM public.route_options route_option
    JOIN public.airports origin ON origin.id = route_option.origin_airport_id
    JOIN public.airports destination ON destination.id = route_option.destination_airport_id
    WHERE origin.iata = 'SGN'
      AND destination.iata = 'LHR'
      AND route_option.stop_count = 0
  ),
  'requires two direct SGN to LHR schedule options'
);

SELECT pg_temp.test_assert(
  (
    SELECT count(*) = 1
    FROM public.route_options route_option
    JOIN public.airports origin ON origin.id = route_option.origin_airport_id
    JOIN public.airports destination ON destination.id = route_option.destination_airport_id
    JOIN public.airports connection
      ON connection.id = route_option.connection_airport_ids[1]
    WHERE origin.iata = 'SGN'
      AND destination.iata = 'LHR'
      AND connection.iata = 'SIN'
      AND route_option.stop_count = 1
      AND route_option.layover_minutes = 135
      AND route_option.total_duration_minutes = 1095
  ),
  'requires one compatible SGN to SIN to LHR option'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM public.route_options route_option
    JOIN public.airports origin
      ON origin.id = route_option.origin_airport_id
    JOIN public.airports destination
      ON destination.id = route_option.destination_airport_id
    JOIN public.airports connection
      ON connection.id = route_option.connection_airport_ids[1]
    WHERE origin.iata = 'SGN'
      AND destination.iata = 'LHR'
      AND connection.iata = 'BKK'
  ),
  'rejects the SGN to BKK to LHR connection shorter than 45 minutes'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM public.route_options route_option
    JOIN public.airports origin ON origin.id = route_option.origin_airport_id
    JOIN public.airports destination ON destination.id = route_option.destination_airport_id
    WHERE origin.iata = 'SGN'
      AND destination.iata = 'CDG'
      AND route_option.stop_count = 0
  ),
  'rejects the inactive direct SGN to CDG route service'
);

ROLLBACK;
