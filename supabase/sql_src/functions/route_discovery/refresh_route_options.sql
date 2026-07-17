-- ============================================================================
-- Function: public.refresh_route_options
-- Feature: Route Discovery
-- Purpose: Rebuild direct and one-stop Route Discovery options atomically.
-- Responsibilities: Enforce route status, schedule overlap, connection bounds, and versioning.
-- Notes: This privileged maintenance operation is executable only by service_role.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.refresh_route_options()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Refresh state
  ------------------------------------------------------------------
  v_data_version UUID := gen_random_uuid();
  v_direct_count INTEGER := 0;
  v_one_stop_count INTEGER := 0;
BEGIN
  -- STEP 01: Serialize refreshes and replace the prior read model in this transaction.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('public.refresh_route_options', 0)
  );
  DELETE FROM public.route_options;

  -- STEP 02: Materialize schedule options backed by an eligible direct route.
  INSERT INTO public.route_options (
    origin_airport_id,
    destination_airport_id,
    stop_count,
    service_ids,
    connection_airport_ids,
    operating_airline_ids,
    marketing_airline_ids,
    total_flight_minutes,
    layover_minutes,
    total_duration_minutes,
    departure_local_time,
    arrival_local_time,
    arrival_day_offset,
    valid_from,
    valid_to,
    days_of_week,
    confidence_score,
    data_version
  )
  SELECT
    route.origin_airport_id,
    route.destination_airport_id,
    0,
    ARRAY[service.id],
    '{}'::UUID[],
    ARRAY[service.operating_airline_id],
    ARRAY[COALESCE(service.marketing_airline_id, service.operating_airline_id)],
    service.duration_minutes,
    0,
    service.duration_minutes,
    service.departure_local_time,
    service.arrival_local_time,
    service.arrival_day_offset,
    service.valid_from,
    service.valid_to,
    service.days_of_week,
    LEAST(route.confidence_score, service.confidence_score),
    v_data_version
  FROM public.flight_services service
  JOIN public.flight_routes route ON route.id = service.flight_route_id
  WHERE route.status IN ('verified_active', 'likely_active', 'seasonal');

  GET DIAGNOSTICS v_direct_count = ROW_COUNT;

  -- STEP 03: Materialize one-stop pairs with overlapping validity and safe connection time.
  INSERT INTO public.route_options (
    origin_airport_id,
    destination_airport_id,
    stop_count,
    service_ids,
    connection_airport_ids,
    operating_airline_ids,
    marketing_airline_ids,
    total_flight_minutes,
    layover_minutes,
    total_duration_minutes,
    departure_local_time,
    arrival_local_time,
    arrival_day_offset,
    valid_from,
    valid_to,
    days_of_week,
    confidence_score,
    data_version
  )
  SELECT
    first_route.origin_airport_id,
    second_route.destination_airport_id,
    1,
    ARRAY[first_service.id, second_service.id],
    ARRAY[first_route.destination_airport_id],
    ARRAY[first_service.operating_airline_id, second_service.operating_airline_id],
    ARRAY[
      COALESCE(first_service.marketing_airline_id, first_service.operating_airline_id),
      COALESCE(second_service.marketing_airline_id, second_service.operating_airline_id)
    ],
    first_service.duration_minutes + second_service.duration_minutes,
    connection.layover_minutes,
    first_service.duration_minutes
      + connection.layover_minutes
      + second_service.duration_minutes,
    first_service.departure_local_time,
    second_service.arrival_local_time,
    first_service.arrival_day_offset
      + CASE
        WHEN second_service.departure_local_time <= first_service.arrival_local_time THEN 1
        ELSE 0
      END
      + second_service.arrival_day_offset,
    GREATEST(first_service.valid_from, second_service.valid_from),
    LEAST(first_service.valid_to, second_service.valid_to),
    schedule_days.days_of_week,
    LEAST(
      first_route.confidence_score,
      second_route.confidence_score,
      first_service.confidence_score,
      second_service.confidence_score
    ),
    v_data_version
  FROM public.flight_services first_service
  JOIN public.flight_routes first_route ON first_route.id = first_service.flight_route_id
  JOIN public.flight_routes second_route
    ON second_route.origin_airport_id = first_route.destination_airport_id
    AND second_route.destination_airport_id <> first_route.origin_airport_id
  JOIN public.flight_services second_service
    ON second_service.flight_route_id = second_route.id
  CROSS JOIN LATERAL (
    SELECT public.calculate_layover_minutes(
      first_service.arrival_local_time,
      first_service.arrival_day_offset,
      second_service.departure_local_time
    ) AS layover_minutes
  ) connection
  CROSS JOIN LATERAL (
    SELECT ARRAY(
      SELECT day_value
      FROM UNNEST(first_service.days_of_week) day_value
      INTERSECT
      SELECT day_value
      FROM UNNEST(second_service.days_of_week) day_value
      ORDER BY day_value
    )::SMALLINT[] AS days_of_week
  ) schedule_days
  WHERE first_route.status IN ('verified_active', 'likely_active', 'seasonal')
    AND second_route.status IN ('verified_active', 'likely_active', 'seasonal')
    AND GREATEST(first_service.valid_from, second_service.valid_from)
      <= LEAST(first_service.valid_to, second_service.valid_to)
    AND cardinality(schedule_days.days_of_week) > 0
    AND connection.layover_minutes BETWEEN 45 AND 1440;

  GET DIAGNOSTICS v_one_stop_count = ROW_COUNT;

  -- STEP 04: Return refresh metadata for operational logging and verification.
  RETURN jsonb_build_object(
    'data_version', v_data_version,
    'direct_count', v_direct_count,
    'one_stop_count', v_one_stop_count,
    'total_count', v_direct_count + v_one_stop_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_route_options() FROM public;
GRANT EXECUTE ON FUNCTION public.refresh_route_options() TO service_role;
