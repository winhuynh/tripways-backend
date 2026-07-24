-- ============================================================================
-- Function: public.rpc_search_routes
-- Feature: Route Discovery
-- Purpose: Search the precomputed route graph through a stable JSON contract.
-- Responsibilities: Validate filters, resolve codes, rank options, paginate, and return facets.
-- Notes: The service-role-only transport keeps direct table access closed to public clients.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_search_routes(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Route identity
  ------------------------------------------------------------------
  v_from TEXT;
  v_to TEXT;
  v_origin_id UUID;
  v_destination_id UUID;

  ------------------------------------------------------------------
  -- Filters and pagination
  ------------------------------------------------------------------
  v_max_stops INTEGER := 1;
  v_max_duration_minutes INTEGER;
  v_max_layover_minutes INTEGER;
  v_departure_window TEXT;
  v_limit INTEGER := 20;
  v_offset INTEGER := 0;
  v_airline_codes TEXT[] := '{}'::TEXT[];
  v_excluded_airport_ids UUID[] := '{}'::UUID[];

  ------------------------------------------------------------------
  -- Result
  ------------------------------------------------------------------
  v_result JSONB;
BEGIN
  -- STEP 01: Validate and normalize the bounded public input contract.
  IF p_input IS NULL OR jsonb_typeof(p_input) <> 'object' THEN
    RETURN private.build_rpc_error(
      '[]'::JSONB,
      'ERR_INVALID_REQUEST',
      'Request must be a JSON object.'
    );
  END IF;

  v_from := private.normalize_airport_iata(p_input->>'from');
  v_to := private.normalize_airport_iata(p_input->>'to');

  IF v_from IS NULL OR v_to IS NULL OR v_from = v_to THEN
    RETURN private.build_rpc_error(
      '[]'::JSONB,
      'ERR_INVALID_REQUEST',
      'Origin and destination must be different three-letter IATA codes.'
    );
  END IF;

  IF p_input ? 'max_stops' THEN
    IF jsonb_typeof(p_input->'max_stops') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_stops must be an integer.'
        )
      );
    END IF;
    v_max_stops := (p_input->>'max_stops')::INTEGER;
  END IF;

  IF p_input ? 'limit' THEN
    IF jsonb_typeof(p_input->'limit') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'limit must be an integer.'
        )
      );
    END IF;
    v_limit := (p_input->>'limit')::INTEGER;
  END IF;

  IF p_input ? 'offset' THEN
    IF jsonb_typeof(p_input->'offset') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'offset must be an integer.'
        )
      );
    END IF;
    v_offset := (p_input->>'offset')::INTEGER;
  END IF;

  IF v_max_stops NOT BETWEEN 0 AND 1
    OR v_limit NOT BETWEEN 1 AND 100
    OR v_offset NOT BETWEEN 0 AND 10000
  THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'Pagination or stop limits are outside accepted bounds.'
      )
    );
  END IF;

  IF p_input ? 'max_duration_minutes' THEN
    IF jsonb_typeof(p_input->'max_duration_minutes') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_duration_minutes must be an integer.'
        )
      );
    END IF;
    v_max_duration_minutes := (p_input->>'max_duration_minutes')::INTEGER;
    IF v_max_duration_minutes NOT BETWEEN 1 AND 4320 THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_duration_minutes is outside accepted bounds.'
        )
      );
    END IF;
  END IF;

  IF p_input ? 'max_layover_minutes' THEN
    IF jsonb_typeof(p_input->'max_layover_minutes') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_layover_minutes must be an integer.'
        )
      );
    END IF;
    v_max_layover_minutes := (p_input->>'max_layover_minutes')::INTEGER;
    IF v_max_layover_minutes NOT BETWEEN 45 AND 1440 THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_layover_minutes is outside accepted bounds.'
        )
      );
    END IF;
  END IF;

  v_departure_window := nullif(lower(btrim(COALESCE(p_input->>'departure_window', ''))), '');
  IF v_departure_window IS NOT NULL
    AND v_departure_window NOT IN ('morning', 'afternoon', 'evening', 'night') THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'departure_window is not supported.'
      )
    );
  END IF;

  IF p_input ? 'airlines' THEN
    IF jsonb_typeof(p_input->'airlines') <> 'array' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'airlines must be an array.'
        )
      );
    END IF;
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(p_input->'airlines') code
      WHERE private.normalize_airline_iata(code) IS NULL
    ) THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'airlines contains an invalid IATA code.'
        )
      );
    END IF;
    SELECT COALESCE(
      array_agg(DISTINCT private.normalize_airline_iata(code)),
      '{}'::TEXT[]
    )
    INTO v_airline_codes
    FROM jsonb_array_elements_text(p_input->'airlines') code;
  END IF;

  IF p_input ? 'exclude_airports' THEN
    IF jsonb_typeof(p_input->'exclude_airports') <> 'array' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'exclude_airports must be an array.'
        )
      );
    END IF;
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(p_input->'exclude_airports') code
      WHERE private.normalize_airport_iata(code) IS NULL
    ) THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'exclude_airports contains an invalid IATA code.'
        )
      );
    END IF;
    SELECT COALESCE(array_agg(airport.id), '{}'::UUID[])
    INTO v_excluded_airport_ids
    FROM public.airports airport
    WHERE airport.iata IN (
      SELECT private.normalize_airport_iata(code)
      FROM jsonb_array_elements_text(p_input->'exclude_airports') code
    );
  END IF;

  -- STEP 02: Resolve endpoint codes without exposing internal identifiers.
  SELECT airport.id INTO v_origin_id FROM public.airports airport WHERE airport.iata = v_from;
  SELECT airport.id INTO v_destination_id FROM public.airports airport WHERE airport.iata = v_to;

  IF v_origin_id IS NULL OR v_destination_id IS NULL THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_AIRPORT_NOT_FOUND',
        'message', 'Origin or destination airport was not found.'
      )
    );
  END IF;

  -- STEP 03: Apply all route filters once, then derive results and facets from the same set.
  WITH filtered AS MATERIALIZED (
    SELECT route_option.*
    FROM public.route_options route_option
    WHERE route_option.origin_airport_id = v_origin_id
      AND route_option.destination_airport_id = v_destination_id
      AND route_option.stop_count <= v_max_stops
      AND (
        v_max_duration_minutes IS NULL
        OR route_option.total_duration_minutes <= v_max_duration_minutes
      )
      AND (v_max_layover_minutes IS NULL OR route_option.layover_minutes <= v_max_layover_minutes)
      AND NOT (route_option.connection_airport_ids && v_excluded_airport_ids)
      AND (
        cardinality(v_airline_codes) = 0
        OR EXISTS (
          SELECT 1
          FROM public.airlines airline
          WHERE airline.id = ANY(route_option.operating_airline_ids)
            AND airline.iata = ANY(v_airline_codes)
        )
      )
      AND (
        v_departure_window IS NULL
        OR (
          v_departure_window = 'morning'
          AND route_option.departure_local_time >= TIME '05:00'
          AND route_option.departure_local_time < TIME '12:00'
        )
        OR (
          v_departure_window = 'afternoon'
          AND route_option.departure_local_time >= TIME '12:00'
          AND route_option.departure_local_time < TIME '17:00'
        )
        OR (
          v_departure_window = 'evening'
          AND route_option.departure_local_time >= TIME '17:00'
          AND route_option.departure_local_time < TIME '21:00'
        )
        OR (
          v_departure_window = 'night'
          AND (
            route_option.departure_local_time >= TIME '21:00'
            OR route_option.departure_local_time < TIME '05:00'
          )
        )
      )
  ),
  page AS (
    SELECT *
    FROM filtered
    ORDER BY stop_count, total_duration_minutes, confidence_score DESC, id
    LIMIT v_limit
    OFFSET v_offset
  )
  SELECT jsonb_build_object(
    'data', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', page.id,
          'from', v_from,
          'to', v_to,
          'stops', page.stop_count,
          'connection_airports', COALESCE((
            SELECT jsonb_agg(airport.iata ORDER BY position.ordinality)
            FROM UNNEST(page.connection_airport_ids)
            WITH ORDINALITY position(airport_id, ordinality)
            JOIN public.airports airport ON airport.id = position.airport_id
          ), '[]'::JSONB),
          'operating_airlines', COALESCE((
            SELECT jsonb_agg(airline.iata ORDER BY position.ordinality)
            FROM UNNEST(page.operating_airline_ids) WITH ordinality position(airline_id, ordinality)
            JOIN public.airlines airline ON airline.id = position.airline_id
          ), '[]'::JSONB),
          'total_flight_minutes', page.total_flight_minutes,
          'layover_minutes', page.layover_minutes,
          'total_duration_minutes', page.total_duration_minutes,
          'departure_local_time', to_char(page.departure_local_time, 'HH24:MI'),
          'arrival_local_time', to_char(page.arrival_local_time, 'HH24:MI'),
          'arrival_day_offset', page.arrival_day_offset,
          'valid_from', page.valid_from,
          'valid_to', page.valid_to,
          'days_of_week', page.days_of_week,
          'confidence_score', page.confidence_score,
          'data_version', page.data_version
        )
        ORDER BY page.stop_count, page.total_duration_minutes, page.confidence_score DESC, page.id
      )
      FROM page
    ), '[]'::JSONB),
    'meta', jsonb_build_object(
      'total', (SELECT count(*) FROM filtered),
      'limit', v_limit,
      'offset', v_offset,
      'facets', jsonb_build_object(
        'stops', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object('value', stop_count, 'count', option_count)
            ORDER BY stop_count
          )
          FROM (
            SELECT filtered.stop_count, count(*) AS option_count
            FROM filtered
            GROUP BY filtered.stop_count
          ) stop_facet
        ), '[]'::JSONB),
        'airlines', COALESCE((
          SELECT jsonb_agg(jsonb_build_object('value', iata, 'count', option_count) ORDER BY iata)
          FROM (
            SELECT airline.iata, count(DISTINCT filtered.id) AS option_count
            FROM filtered
            CROSS JOIN LATERAL UNNEST(filtered.operating_airline_ids) airline_id
            JOIN public.airlines airline ON airline.id = airline_id
            GROUP BY airline.iata
          ) airline_facet
        ), '[]'::JSONB)
      )
    ),
    'error', NULL
  )
  INTO v_result;

  -- STEP 04: Return one deterministic envelope for transport-level normalization.
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_routes(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_search_routes(JSONB) TO service_role;
