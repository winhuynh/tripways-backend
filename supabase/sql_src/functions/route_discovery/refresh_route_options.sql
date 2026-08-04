-- ============================================================================
-- Function: public.refresh_route_options
-- Feature: Route Discovery
-- Purpose: Rebuild direct through three-stop route options atomically.
-- Responsibilities: Bound graph expansion, reject cycles, enforce schedule compatibility, and version results.
-- Notes: Stored discovery is not live availability and never creates fare or baggage claims.
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
  v_total_count  INTEGER := 0;
  v_counts       JSONB := '{}'::JSONB;
BEGIN
  -- STEP 01: Serialize refreshes and replace the prior version atomically.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('public.refresh_route_options', 0)
  );
  DELETE FROM public.route_options;

  -- STEP 02: Expand eligible schedule paths to at most four legs (three stops).
  INSERT INTO public.route_options (
    origin_airport_id,
    destination_airport_id,
    stop_count,
    service_ids,
    flight_route_ids,
    origin_airport_ids,
    destination_airport_ids,
    connection_airport_ids,
    operating_airline_ids,
    marketing_airline_ids,
    departure_local_times,
    arrival_local_times,
    leg_duration_minutes,
    layover_minutes_by_connection,
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
  WITH RECURSIVE route_paths AS (
    SELECT
      route.origin_airport_id,
      route.destination_airport_id,
      ARRAY[route.origin_airport_id, route.destination_airport_id]::UUID[] AS airport_path,
      ARRAY[service.id]::UUID[] AS service_ids,
      ARRAY[route.id]::UUID[] AS flight_route_ids,
      ARRAY[route.origin_airport_id]::UUID[] AS origin_airport_ids,
      ARRAY[route.destination_airport_id]::UUID[] AS destination_airport_ids,
      '{}'::UUID[] AS connection_airport_ids,
      ARRAY[service.operating_airline_id]::UUID[] AS operating_airline_ids,
      ARRAY[COALESCE(service.marketing_airline_id, service.operating_airline_id)]::UUID[] AS marketing_airline_ids,
      ARRAY[service.departure_local_time]::TIME[] AS departure_local_times,
      ARRAY[service.arrival_local_time]::TIME[] AS arrival_local_times,
      ARRAY[service.duration_minutes]::INTEGER[] AS leg_duration_minutes,
      '{}'::INTEGER[] AS layover_minutes_by_connection,
      service.duration_minutes AS total_flight_minutes,
      0 AS layover_minutes,
      service.duration_minutes AS total_duration_minutes,
      service.departure_local_time,
      service.arrival_local_time,
      service.arrival_day_offset::INTEGER AS arrival_day_offset,
      service.valid_from,
      service.valid_to,
      service.days_of_week,
      LEAST(route.confidence_score, service.confidence_score)::NUMERIC(4,3) AS confidence_score
    FROM public.flight_services service
    JOIN public.flight_routes route
      ON route.id = service.flight_route_id
    JOIN admin.data_sources source
      ON source.id = route.source_id
    WHERE route.status IN ('verified_active', 'likely_active', 'seasonal')
      AND (
        source.derived_data_allowed = TRUE
        OR source.source_type = 'development_fixture'
      )

    UNION ALL

    SELECT
      path.origin_airport_id,
      next_route.destination_airport_id,
      path.airport_path || next_route.destination_airport_id,
      path.service_ids || next_service.id,
      path.flight_route_ids || next_route.id,
      path.origin_airport_ids || next_route.origin_airport_id,
      path.destination_airport_ids || next_route.destination_airport_id,
      path.connection_airport_ids || next_route.origin_airport_id,
      path.operating_airline_ids || next_service.operating_airline_id,
      path.marketing_airline_ids || COALESCE(next_service.marketing_airline_id, next_service.operating_airline_id),
      path.departure_local_times || next_service.departure_local_time,
      path.arrival_local_times || next_service.arrival_local_time,
      path.leg_duration_minutes || next_service.duration_minutes,
      path.layover_minutes_by_connection || connection.layover_minutes,
      path.total_flight_minutes + next_service.duration_minutes,
      path.layover_minutes + connection.layover_minutes,
      path.total_duration_minutes + connection.layover_minutes + next_service.duration_minutes,
      path.departure_local_time,
      next_service.arrival_local_time,
      path.arrival_day_offset
        + CASE WHEN next_service.departure_local_time <= path.arrival_local_time THEN 1 ELSE 0 END
        + next_service.arrival_day_offset,
      GREATEST(path.valid_from, next_service.valid_from),
      LEAST(path.valid_to, next_service.valid_to),
      schedule_days.days_of_week,
      LEAST(path.confidence_score, next_route.confidence_score, next_service.confidence_score)::NUMERIC(4,3)
    FROM route_paths path
    JOIN public.flight_routes next_route
      ON next_route.origin_airport_id = path.destination_airport_id
    JOIN public.flight_services next_service
      ON next_service.flight_route_id = next_route.id
    JOIN admin.data_sources next_source
      ON next_source.id = next_route.source_id
    CROSS JOIN LATERAL (
      SELECT public.calculate_layover_minutes(
        path.arrival_local_time,
        path.arrival_day_offset::SMALLINT,
        next_service.departure_local_time
      ) AS layover_minutes
    ) connection
    CROSS JOIN LATERAL (
      SELECT ARRAY(
        SELECT day_value
        FROM UNNEST(path.days_of_week) day_value
        INTERSECT
        SELECT day_value
        FROM UNNEST(next_service.days_of_week) day_value
        ORDER BY day_value
      )::SMALLINT[] AS days_of_week
    ) schedule_days
    WHERE cardinality(path.service_ids) < 4
      AND next_route.status IN ('verified_active', 'likely_active', 'seasonal')
      AND (
        next_source.derived_data_allowed = TRUE
        OR next_source.source_type = 'development_fixture'
      )
      AND NOT (next_route.destination_airport_id = ANY(path.airport_path))
      AND next_route.destination_airport_id <> path.origin_airport_id
      AND GREATEST(path.valid_from, next_service.valid_from)
        <= LEAST(path.valid_to, next_service.valid_to)
      AND cardinality(schedule_days.days_of_week) > 0
      AND connection.layover_minutes BETWEEN 45 AND 1440
      AND path.total_duration_minutes + connection.layover_minutes + next_service.duration_minutes <= 10080
      AND path.arrival_day_offset
        + CASE WHEN next_service.departure_local_time <= path.arrival_local_time THEN 1 ELSE 0 END
        + next_service.arrival_day_offset <= 7
  ),
  ranked_paths AS (
    SELECT
      path.*,
      ROW_NUMBER() OVER (
        PARTITION BY path.origin_airport_id, path.destination_airport_id, cardinality(path.service_ids)
        ORDER BY path.total_duration_minutes, path.confidence_score DESC, path.service_ids::TEXT
      ) AS candidate_rank
    FROM route_paths path
  )
  SELECT
    path.origin_airport_id,
    path.destination_airport_id,
    (cardinality(path.service_ids) - 1)::SMALLINT,
    path.service_ids,
    path.flight_route_ids,
    path.origin_airport_ids,
    path.destination_airport_ids,
    path.connection_airport_ids,
    path.operating_airline_ids,
    path.marketing_airline_ids,
    path.departure_local_times,
    path.arrival_local_times,
    path.leg_duration_minutes,
    path.layover_minutes_by_connection,
    path.total_flight_minutes,
    path.layover_minutes,
    path.total_duration_minutes,
    path.departure_local_time,
    path.arrival_local_time,
    path.arrival_day_offset::SMALLINT,
    path.valid_from,
    path.valid_to,
    path.days_of_week,
    path.confidence_score,
    v_data_version
  FROM ranked_paths path
  WHERE path.candidate_rank <= 200;

  GET DIAGNOSTICS v_total_count = ROW_COUNT;

  -- STEP 03: Return versioned counts by stop depth for operational verification.
  SELECT COALESCE(
    jsonb_object_agg(stop_count::TEXT, option_count ORDER BY stop_count),
    '{}'::JSONB
  )
  INTO v_counts
  FROM (
    SELECT stop_count, COUNT(*) AS option_count
    FROM public.route_options
    GROUP BY stop_count
  ) counts;

  RETURN jsonb_build_object(
    'data_version', v_data_version,
    'counts_by_stop', v_counts,
    'total_count', v_total_count,
    'max_stops', 3
  );
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_route_options() FROM public;
GRANT EXECUTE ON FUNCTION public.refresh_route_options() TO service_role;
