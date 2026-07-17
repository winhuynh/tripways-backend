-- ============================================================================
-- Function: public.calculate_layover_minutes
-- Feature: Route Discovery
-- Purpose: Calculate connection time using two local timestamps at the same airport.
-- Responsibilities: Normalize a same-day or next-day departure into a positive minute interval.
-- Notes: The caller applies the accepted minimum and maximum connection bounds.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_layover_minutes(
  p_arrival_local_time TIME,
  p_arrival_day_offset SMALLINT,
  p_next_departure_local_time TIME
)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
  WITH minute_values AS (
    SELECT
      (
        p_arrival_day_offset::INTEGER * 1440
        + extract(HOUR FROM p_arrival_local_time)::INTEGER * 60
        + extract(MINUTE FROM p_arrival_local_time)::INTEGER
      ) AS arrival_minute,
      (
        extract(HOUR FROM p_next_departure_local_time)::INTEGER * 60
        + extract(MINUTE FROM p_next_departure_local_time)::INTEGER
      ) AS departure_minute
  )
  SELECT
    CASE
      WHEN mod(mod(departure_minute - arrival_minute, 1440) + 1440, 1440) = 0
        THEN 1440
      ELSE mod(mod(departure_minute - arrival_minute, 1440) + 1440, 1440)
    END
  FROM minute_values;
$$;

REVOKE ALL ON FUNCTION public.calculate_layover_minutes(TIME, SMALLINT, TIME) FROM public;
GRANT EXECUTE ON FUNCTION public.calculate_layover_minutes(TIME, SMALLINT, TIME) TO service_role;
