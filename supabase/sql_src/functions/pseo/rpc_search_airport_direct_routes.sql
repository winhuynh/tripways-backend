-- ============================================================================
-- Function: public.rpc_search_airport_direct_routes
-- Feature: Interactive pSEO
-- Purpose: Search inbound or outbound direct routes for one airport.
-- Responsibilities: Validate bounded filters and derive results/facets from one filtered relation.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_search_airport_direct_routes(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_identity JSONB;
  v_context JSONB;
  v_airport_iata TEXT;
  v_locale TEXT;
  v_direction TEXT;
  v_airport_id UUID;
  v_airport_page_id UUID;
  v_data_version UUID;
  v_airlines TEXT[] := '{}'::TEXT[];
  v_countries TEXT[] := '{}'::TEXT[];
  v_seasonality TEXT;
  v_max_duration_minutes INTEGER;
  v_limit INTEGER := 20;
  v_offset INTEGER := 0;
  v_result JSONB;
BEGIN
  v_identity := private.parse_airport_page_identity(p_input);

  IF v_identity->'error' IS NOT NULL
    AND v_identity->'error' <> 'null'::JSONB
  THEN
    RETURN jsonb_build_object('data', NULL, 'meta', NULL, 'error', v_identity->'error');
  END IF;

  v_airport_iata := v_identity #>> '{data,airport_iata}';
  v_locale := v_identity #>> '{data,locale}';
  v_direction := lower(btrim(COALESCE(p_input->>'direction', 'outbound')));

  IF v_direction NOT IN ('outbound', 'inbound') THEN
    RETURN jsonb_build_object(
      'data', NULL,
      'meta', NULL,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'direction must be outbound or inbound.'
      )
    );
  END IF;

  IF p_input ? 'airlines' THEN
    IF jsonb_typeof(p_input->'airlines') <> 'array'
      OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(p_input->'airlines') item
        WHERE upper(btrim(item)) !~ '^[A-Z0-9]{2}$'
      )
    THEN
      RETURN jsonb_build_object(
        'data', NULL,
        'meta', NULL,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'airlines must contain valid IATA codes.'
        )
      );
    END IF;

    SELECT COALESCE(array_agg(DISTINCT upper(btrim(item))), '{}'::TEXT[])
    INTO v_airlines
    FROM jsonb_array_elements_text(p_input->'airlines') item;
  END IF;

  IF p_input ? 'countries' THEN
    IF jsonb_typeof(p_input->'countries') <> 'array'
      OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(p_input->'countries') item
        WHERE upper(btrim(item)) !~ '^[A-Z]{2}$'
      )
    THEN
      RETURN jsonb_build_object(
        'data', NULL,
        'meta', NULL,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'countries must contain valid ISO-2 codes.'
        )
      );
    END IF;

    SELECT COALESCE(array_agg(DISTINCT upper(btrim(item))), '{}'::TEXT[])
    INTO v_countries
    FROM jsonb_array_elements_text(p_input->'countries') item;
  END IF;

  IF p_input ? 'seasonality' THEN
    v_seasonality := lower(btrim(p_input->>'seasonality'));
    IF v_seasonality NOT IN ('year_round', 'seasonal', 'unknown') THEN
      RETURN jsonb_build_object(
        'data', NULL,
        'meta', NULL,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'seasonality is invalid.'
        )
      );
    END IF;
  END IF;

  IF p_input ? 'max_duration_minutes' THEN
    IF jsonb_typeof(p_input->'max_duration_minutes') <> 'number'
      OR (p_input->>'max_duration_minutes')::NUMERIC
        <> trunc((p_input->>'max_duration_minutes')::NUMERIC)
      OR (p_input->>'max_duration_minutes')::INTEGER <= 0
    THEN
      RETURN jsonb_build_object(
        'data', NULL,
        'meta', NULL,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_duration_minutes must be a positive integer.'
        )
      );
    END IF;
    v_max_duration_minutes := (p_input->>'max_duration_minutes')::INTEGER;
  END IF;

  IF p_input ? 'limit' THEN
    IF jsonb_typeof(p_input->'limit') <> 'number'
      OR (p_input->>'limit')::NUMERIC <> trunc((p_input->>'limit')::NUMERIC)
      OR (p_input->>'limit')::INTEGER NOT BETWEEN 1 AND 100
    THEN
      RETURN jsonb_build_object(
        'data', NULL,
        'meta', NULL,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'limit must be an integer between 1 and 100.'
        )
      );
    END IF;
    v_limit := (p_input->>'limit')::INTEGER;
  END IF;

  IF p_input ? 'offset' THEN
    IF jsonb_typeof(p_input->'offset') <> 'number'
      OR (p_input->>'offset')::NUMERIC <> trunc((p_input->>'offset')::NUMERIC)
      OR (p_input->>'offset')::INTEGER < 0
    THEN
      RETURN jsonb_build_object(
        'data', NULL,
        'meta', NULL,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'offset must be a non-negative integer.'
        )
      );
    END IF;
    v_offset := (p_input->>'offset')::INTEGER;
  END IF;

  v_context := private.resolve_airport_page_context(v_airport_iata, v_locale);

  IF v_context->'error' IS NOT NULL
    AND v_context->'error' <> 'null'::JSONB
  THEN
    RETURN jsonb_build_object('data', NULL, 'meta', NULL, 'error', v_context->'error');
  END IF;

  v_airport_id := (v_context #>> '{data,airport_id}')::UUID;
  v_airport_page_id := (v_context #>> '{data,airport_page_id}')::UUID;
  v_data_version := (v_context #>> '{data,data_version}')::UUID;

  WITH normalized_routes AS (
    SELECT
      route.flight_route_id,
      CASE WHEN v_direction = 'outbound' THEN destination_airport.id ELSE origin_airport.id END
        AS counterpart_airport_id,
      CASE WHEN v_direction = 'outbound' THEN destination_airport.iata ELSE origin_airport.iata END
        AS counterpart_airport_iata,
      CASE WHEN v_direction = 'outbound' THEN destination_airport.name ELSE origin_airport.name END
        AS counterpart_airport_name,
      CASE WHEN v_direction = 'outbound' THEN destination_city.id ELSE origin_city.id END
        AS counterpart_city_id,
      CASE WHEN v_direction = 'outbound' THEN destination_city.name ELSE origin_city.name END
        AS counterpart_city_name,
      CASE WHEN v_direction = 'outbound' THEN destination_city.slug ELSE origin_city.slug END
        AS counterpart_city_slug,
      CASE WHEN v_direction = 'outbound' THEN destination_country.iso2 ELSE origin_country.iso2 END
        AS counterpart_country_code,
      CASE WHEN v_direction = 'outbound' THEN destination_country.name ELSE origin_country.name END
        AS counterpart_country_name,
      airline.iata AS airline_iata,
      airline.name AS airline_name,
      route.frequency_per_week,
      route.shortest_duration_minutes,
      route.longest_duration_minutes,
      route.seasonality
    FROM public.pseo_direct_routes route
    JOIN public.airports origin_airport
      ON origin_airport.id = route.origin_airport_id
    JOIN public.airports destination_airport
      ON destination_airport.id = route.destination_airport_id
    JOIN public.cities origin_city
      ON origin_city.id = route.origin_city_id
    JOIN public.cities destination_city
      ON destination_city.id = route.destination_city_id
    JOIN public.countries origin_country
      ON origin_country.id = route.origin_country_id
    JOIN public.countries destination_country
      ON destination_country.id = route.destination_country_id
    JOIN public.airlines airline
      ON airline.id = route.operating_airline_id
    WHERE route.data_version = v_data_version
      AND (
        (v_direction = 'outbound' AND route.origin_airport_id = v_airport_id)
        OR
        (v_direction = 'inbound' AND route.destination_airport_id = v_airport_id)
      )
  ),
  filtered_routes AS (
    SELECT *
    FROM normalized_routes route
    WHERE (cardinality(v_airlines) = 0 OR route.airline_iata = ANY(v_airlines))
      AND (cardinality(v_countries) = 0 OR route.counterpart_country_code = ANY(v_countries))
      AND (v_seasonality IS NULL OR route.seasonality = v_seasonality)
      AND (
        v_max_duration_minutes IS NULL
        OR route.shortest_duration_minutes <= v_max_duration_minutes
      )
  ),
  grouped_routes AS (
    SELECT
      counterpart_airport_id,
      counterpart_airport_iata,
      counterpart_airport_name,
      counterpart_city_id,
      counterpart_city_name,
      counterpart_city_slug,
      counterpart_country_code,
      counterpart_country_name,
      count(DISTINCT flight_route_id)::INTEGER AS route_count,
      count(DISTINCT airline_iata)::INTEGER AS airline_count,
      jsonb_agg(DISTINCT airline_iata ORDER BY airline_iata) AS airlines,
      CASE WHEN count(frequency_per_week) = 0 THEN NULL ELSE sum(frequency_per_week) END
        AS frequency_per_week,
      min(shortest_duration_minutes) AS shortest_duration_minutes,
      max(longest_duration_minutes) AS longest_duration_minutes
    FROM filtered_routes
    GROUP BY
      counterpart_airport_id,
      counterpart_airport_iata,
      counterpart_airport_name,
      counterpart_city_id,
      counterpart_city_name,
      counterpart_city_slug,
      counterpart_country_code,
      counterpart_country_name
  ),
  page AS (
    SELECT *
    FROM grouped_routes
    ORDER BY
      COALESCE(frequency_per_week, 0) DESC,
      route_count DESC,
      counterpart_city_name,
      counterpart_airport_iata
    LIMIT v_limit
    OFFSET v_offset
  )
  SELECT jsonb_build_object(
    'data', COALESCE((
      SELECT jsonb_agg(to_jsonb(page_item))
      FROM page page_item
    ), '[]'::JSONB),
    'meta', jsonb_build_object(
      'direction', v_direction,
      'total', (SELECT count(*) FROM grouped_routes),
      'limit', v_limit,
      'offset', v_offset,
      'facets', jsonb_build_object(
        'airlines', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object('code', facet.airline_iata, 'name', facet.airline_name, 'count', facet.count)
            ORDER BY facet.count DESC, facet.airline_iata
          )
          FROM (
            SELECT airline_iata, min(airline_name) AS airline_name, count(*)::INTEGER AS count
            FROM filtered_routes
            GROUP BY airline_iata
          ) facet
        ), '[]'::JSONB),
        'countries', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'code', facet.counterpart_country_code,
              'name', facet.counterpart_country_name,
              'count', facet.count
            )
            ORDER BY facet.count DESC, facet.counterpart_country_code
          )
          FROM (
            SELECT
              counterpart_country_code,
              min(counterpart_country_name) AS counterpart_country_name,
              count(*)::INTEGER AS count
            FROM filtered_routes
            GROUP BY counterpart_country_code
          ) facet
        ), '[]'::JSONB)
      ),
      'data_version', airport_page.data_version,
      'canonical_path', pseo_page.canonical_path,
      'is_indexable', airport_page.is_indexable
    ),
    'error', NULL
  )
  INTO v_result
  FROM public.airport_pages airport_page
  JOIN public.pseo_pages pseo_page
    ON pseo_page.id = airport_page.pseo_page_id
  WHERE airport_page.id = v_airport_page_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_airport_direct_routes(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_search_airport_direct_routes(JSONB) TO service_role;
