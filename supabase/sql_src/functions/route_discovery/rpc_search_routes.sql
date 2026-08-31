-- ============================================================================
-- Function: public.rpc_search_routes
-- Purpose: Search the pre-computed 0-stop and 1-stop route projections.
-- Responsibilities: Validate supported filters and return a bounded public route payload.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_search_routes(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_version_id            UUID;
  v_scope_type            TEXT;
  v_scope_key             TEXT;
  v_scope_from            TEXT;
  v_scope_to              TEXT;
  v_page_size             INTEGER;
  v_max_stops             INTEGER;
  v_max_duration_minutes  INTEGER;
  v_result                JSONB;
BEGIN
  IF jsonb_typeof(p_input) IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_input->'scope') IS DISTINCT FROM 'object'
  THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  v_scope_type := p_input #>> '{scope,type}';
  v_scope_key := p_input #>> '{scope,key}';
  v_scope_from := p_input #>> '{scope,from}';
  v_scope_to := p_input #>> '{scope,to}';
  v_page_size := COALESCE((p_input->>'page_size')::INTEGER, 20);
  v_max_stops := NULLIF(p_input #>> '{filters,max_stops}', '')::INTEGER;
  v_max_duration_minutes := NULLIF(p_input #>> '{filters,max_duration_minutes}', '')::INTEGER;

  IF v_scope_type NOT IN ('global', 'origin_city', 'origin_airport', 'airport', 'city_pair')
    OR v_page_size NOT BETWEEN 1 AND 100
    OR (v_max_stops IS NOT NULL AND v_max_stops NOT IN (0, 1))
    OR (v_max_duration_minutes IS NOT NULL AND v_max_duration_minutes <= 0)
    OR (
      v_scope_type IN ('origin_city', 'origin_airport', 'airport')
      AND NULLIF(btrim(COALESCE(v_scope_key, '')), '') IS NULL
    )
    OR (
      v_scope_type = 'airport'
      AND (p_input #>> '{scope,direction}') NOT IN ('from', 'to')
    )
    OR (
      v_scope_type = 'city_pair'
      AND (
        NULLIF(v_scope_from, '') IS NULL
        OR NULLIF(v_scope_to, '') IS NULL
        OR v_scope_from = v_scope_to
      )
    )
  THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  SELECT version.id
  INTO v_version_id
  FROM public.publication_versions AS version
  WHERE version.is_current = TRUE;

  IF v_version_id IS NULL THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_ROUTE_DISCOVERY_UNAVAILABLE', 'No route publication is available.');
  END IF;

  WITH filtered AS (
    SELECT option.*
    FROM public.flight_route_options option
    WHERE option.publication_version_id = v_version_id
      AND (v_scope_type <> 'origin_city' OR option.origin_city_slug = v_scope_key)
      AND (v_scope_type <> 'origin_airport' OR option.origin_airport_iata = upper(v_scope_key))
      AND (
        v_scope_type <> 'airport'
        OR (
          (p_input #>> '{scope,direction}' = 'from' AND option.origin_airport_iata = upper(v_scope_key))
          OR (p_input #>> '{scope,direction}' = 'to' AND option.destination_airport_iata = upper(v_scope_key))
        )
      )
      AND (
        v_scope_type <> 'city_pair'
        OR (
          option.origin_city_slug = v_scope_from
          AND option.destination_city_slug = v_scope_to
        )
      )
      AND (v_max_stops IS NULL OR option.stops <= v_max_stops)
      AND (v_max_duration_minutes IS NULL OR option.total_duration_minutes <= v_max_duration_minutes)
    ORDER BY option.stops ASC, option.total_duration_minutes ASC, option.confidence_score DESC, option.id
    LIMIT v_page_size
  )
  SELECT jsonb_build_object(
    'data', COALESCE(jsonb_agg(jsonb_build_object(
      'from', origin_airport_iata,
      'to', destination_airport_iata,
      'origin_city_slug', origin_city_slug,
      'destination_city_slug', destination_city_slug,
      'stops', stops,
      'layover_airports', layover_airports,
      'operating_airlines', operating_airlines,
      'flight_numbers', flight_numbers,
      'flight_durations_minutes', flight_durations_minutes,
      'total_duration_minutes', total_duration_minutes,
      'total_distance_km', total_distance_km,
      'days_of_week', days_of_week,
      'route_type', route_type,
      'route_path', route_path,
      'confidence_score', confidence_score
    ) ORDER BY stops ASC, total_duration_minutes ASC, confidence_score DESC, id), '[]'::JSONB),
    'meta', jsonb_build_object(
      'data_version', 'v_' || md5(v_version_id::TEXT),
      'page_size', v_page_size
    ),
    'error', NULL
  ) INTO v_result FROM filtered;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_routes(JSONB) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_search_routes(JSONB) TO service_role;
