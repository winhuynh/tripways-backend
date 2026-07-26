-- ============================================================================
-- Function: public.rpc_get_city_route_map
-- Feature: Route Map
-- Purpose: Return one independently loadable city direct-route map read model.
-- Responsibilities: Validate filters, resolve page context, and compose the RPC envelope.
-- Notes: The first contract supports city origins; airport-origin support is intentionally deferred.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_city_route_map(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Input and resolved context
  ------------------------------------------------------------------
  v_identity JSONB := private.parse_city_page_identity(p_input);
  v_context JSONB;
  v_city_slug TEXT;
  v_locale TEXT;
  v_city_id UUID;
  v_data_version UUID;

  ------------------------------------------------------------------
  -- Filters and bounds
  ------------------------------------------------------------------
  v_origin_airports TEXT[] := '{}'::TEXT[];
  v_airlines TEXT[] := '{}'::TEXT[];
  v_destination_countries TEXT[] := '{}'::TEXT[];
  v_max_duration_minutes INTEGER;
  v_departure_window TEXT;
  v_limit INTEGER := 100;

  ------------------------------------------------------------------
  -- Result
  ------------------------------------------------------------------
  v_route_map JSONB;
BEGIN
  -- STEP 01: Validate the shared city-page identity.
  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      v_identity #>> '{error,code}',
      v_identity #>> '{error,message}'
    );
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';

  -- STEP 02: Normalize bounded route-map filters.
  IF p_input ? 'origin_airports' THEN
    IF jsonb_typeof(p_input->'origin_airports') <> 'array'
      OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(p_input->'origin_airports') code
        WHERE private.normalize_airport_iata(code) IS NULL
      )
    THEN
      RETURN private.build_rpc_error(
        'null'::JSONB,
        'ERR_INVALID_REQUEST',
        'origin_airports must contain valid IATA codes.'
      );
    END IF;

    SELECT COALESCE(
      array_agg(DISTINCT private.normalize_airport_iata(code)),
      '{}'::TEXT[]
    )
    INTO v_origin_airports
    FROM jsonb_array_elements_text(p_input->'origin_airports') code;
  END IF;

  IF p_input ? 'airlines' THEN
    IF jsonb_typeof(p_input->'airlines') <> 'array'
      OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(p_input->'airlines') code
        WHERE private.normalize_airline_iata(code) IS NULL
      )
    THEN
      RETURN private.build_rpc_error(
        'null'::JSONB,
        'ERR_INVALID_REQUEST',
        'airlines must contain valid IATA codes.'
      );
    END IF;

    SELECT COALESCE(
      array_agg(DISTINCT private.normalize_airline_iata(code)),
      '{}'::TEXT[]
    )
    INTO v_airlines
    FROM jsonb_array_elements_text(p_input->'airlines') code;
  END IF;

  IF p_input ? 'destination_countries' THEN
    IF jsonb_typeof(p_input->'destination_countries') <> 'array' THEN
      RETURN private.build_rpc_error(
        'null'::JSONB,
        'ERR_INVALID_REQUEST',
        'destination_countries must be an array.'
      );
    END IF;

    SELECT COALESCE(
      array_agg(DISTINCT upper(btrim(code))),
      '{}'::TEXT[]
    )
    INTO v_destination_countries
    FROM jsonb_array_elements_text(p_input->'destination_countries') code;

    IF EXISTS (
      SELECT 1
      FROM UNNEST(v_destination_countries) code
      WHERE code !~ '^[A-Z]{2}$'
    ) THEN
      RETURN private.build_rpc_error(
        'null'::JSONB,
        'ERR_INVALID_REQUEST',
        'destination_countries contains an invalid ISO code.'
      );
    END IF;
  END IF;

  IF p_input ? 'max_duration_minutes' THEN
    IF jsonb_typeof(p_input->'max_duration_minutes') <> 'number' THEN
      RETURN private.build_rpc_error(
        'null'::JSONB,
        'ERR_INVALID_REQUEST',
        'max_duration_minutes must be an integer.'
      );
    END IF;

    v_max_duration_minutes := (p_input->>'max_duration_minutes')::INTEGER;
    IF v_max_duration_minutes NOT BETWEEN 1 AND 1440 THEN
      RETURN private.build_rpc_error(
        'null'::JSONB,
        'ERR_INVALID_REQUEST',
        'max_duration_minutes is outside accepted bounds.'
      );
    END IF;
  END IF;

  v_departure_window := nullif(
    lower(btrim(COALESCE(p_input->>'departure_window', ''))),
    ''
  );
  IF v_departure_window IS NOT NULL
    AND v_departure_window NOT IN ('morning', 'afternoon', 'evening', 'night')
  THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      'ERR_INVALID_REQUEST',
      'departure_window is not supported.'
    );
  END IF;

  IF p_input ? 'limit' THEN
    IF jsonb_typeof(p_input->'limit') <> 'number' THEN
      RETURN private.build_rpc_error(
        'null'::JSONB,
        'ERR_INVALID_REQUEST',
        'limit must be an integer.'
      );
    END IF;
    v_limit := (p_input->>'limit')::INTEGER;
  END IF;

  IF v_limit NOT BETWEEN 1 AND 100 THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      'ERR_INVALID_REQUEST',
      'limit is outside accepted bounds.'
    );
  END IF;

  -- STEP 03: Resolve the published city-page version.
  v_context := private.resolve_city_page_context(
    v_city_slug,
    v_locale
  );

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      v_context #>> '{error,code}',
      v_context #>> '{error,message}'
    );
  END IF;

  v_city_id := (v_context #>> '{data,city_id}')::UUID;
  v_data_version := (v_context #>> '{data,data_version}')::UUID;

  -- STEP 04: Delegate aggregation and compose the shared envelope.
  v_route_map := private.get_city_route_map(
    v_city_id,
    v_city_slug,
    v_data_version,
    v_origin_airports,
    v_airlines,
    v_destination_countries,
    v_max_duration_minutes,
    v_departure_window,
    v_limit
  );

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'origin', v_route_map->'origin',
      'destinations', v_route_map->'destinations'
    ),
    'meta', jsonb_build_object(
      'city_slug', v_city_slug,
      'locale', v_locale,
      'data_version', v_data_version,
      'total', (v_route_map->>'total')::INTEGER,
      'omitted_destination_count',
        (v_route_map->>'omitted_destination_count')::INTEGER,
      'limit', v_limit,
      'filters', jsonb_build_object(
        'origin_airports', to_jsonb(v_origin_airports),
        'airlines', to_jsonb(v_airlines),
        'destination_countries', to_jsonb(v_destination_countries),
        'max_duration_minutes', v_max_duration_minutes,
        'departure_window', v_departure_window
      )
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_city_route_map(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_city_route_map(JSONB) TO service_role;
