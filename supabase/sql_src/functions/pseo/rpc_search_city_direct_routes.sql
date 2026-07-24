-- ============================================================================
-- Function: public.rpc_search_city_direct_routes
-- Feature: Interactive pSEO
-- Purpose: Filter, facet, rank, and paginate direct destinations from a city.
-- Responsibilities: Validate bounded filters and derive results/facets from one filtered set.
-- Notes: Filter query parameters do not create indexable page identities.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_search_city_direct_routes(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Route identity and version
  ------------------------------------------------------------------
  v_city_slug TEXT;
  v_locale TEXT;
  v_city_id UUID;
  v_data_version UUID;

  ------------------------------------------------------------------
  -- Filters and pagination
  ------------------------------------------------------------------
  v_origin_airports TEXT[] := '{}'::TEXT[];
  v_airlines TEXT[] := '{}'::TEXT[];
  v_destination_countries TEXT[] := '{}'::TEXT[];
  v_max_duration_minutes INTEGER;
  v_departure_window TEXT;
  v_limit INTEGER := 20;
  v_offset INTEGER := 0;

  ------------------------------------------------------------------
  -- Result
  ------------------------------------------------------------------
  v_identity JSONB;
  v_context JSONB;
  v_result JSONB;
BEGIN
  -- STEP 01: Parse the city-page identity shared by pSEO read RPCs.
  v_identity := private.parse_city_page_identity(p_input);

  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      '[]'::JSONB,
      v_identity #>> '{error,code}',
      v_identity #>> '{error,message}'
    );
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';

  IF p_input ? 'origin_airports' THEN
    IF jsonb_typeof(p_input->'origin_airports') <> 'array' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'origin_airports must be an array.'
        )
      );
    END IF;
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(p_input->'origin_airports') code
      WHERE private.normalize_airport_iata(code) IS NULL
    ) THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'origin_airports contains an invalid IATA code.'
        )
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
    INTO v_airlines
    FROM jsonb_array_elements_text(p_input->'airlines') code;
  END IF;

  IF p_input ? 'destination_countries' THEN
    IF jsonb_typeof(p_input->'destination_countries') <> 'array' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'destination_countries must be an array.'
        )
      );
    END IF;
    SELECT COALESCE(array_agg(DISTINCT upper(btrim(code))), '{}'::TEXT[])
    INTO v_destination_countries
    FROM jsonb_array_elements_text(p_input->'destination_countries') code;
    IF EXISTS (
      SELECT 1
      FROM UNNEST(v_destination_countries) code
      WHERE code !~ '^[A-Z]{2}$'
    ) THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'destination_countries contains an invalid ISO code.'
        )
      );
    END IF;
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
    IF v_max_duration_minutes NOT BETWEEN 1 AND 1440 THEN
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

  v_departure_window := nullif(lower(btrim(COALESCE(p_input->>'departure_window', ''))), '');
  IF v_departure_window IS NOT NULL
    AND v_departure_window NOT IN ('morning', 'afternoon', 'evening', 'night')
  THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'departure_window is not supported.'
      )
    );
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

  IF v_limit NOT BETWEEN 1 AND 100 OR v_offset NOT BETWEEN 0 AND 10000 THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'Pagination is outside accepted bounds.'
      )
    );
  END IF;

  -- STEP 02: Resolve the city and current page version.
  v_context := private.resolve_city_page_context(
    v_city_slug,
    v_locale
  );

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      '[]'::JSONB,
      v_context #>> '{error,code}',
      v_context #>> '{error,message}'
    );
  END IF;

  v_city_id := (v_context #>> '{data,city_id}')::UUID;
  v_data_version := (v_context #>> '{data,data_version}')::UUID;

  -- STEP 03: Filter once and derive results and facets from the same relation.
  WITH filtered AS MATERIALIZED (
    SELECT
      city_route.*,
      origin_airport.iata AS origin_airport_iata,
      destination_airport.iata AS destination_airport_iata,
      operating_airline.iata AS operating_airline_iata,
      operating_airline.name AS operating_airline_name,
      destination_country.iso2 AS destination_country_iso2,
      destination_country.name AS destination_country_name,
      destination_city.name AS destination_city_name,
      destination_city.slug AS destination_city_slug
    FROM public.city_direct_routes city_route
    JOIN public.airports origin_airport
      ON origin_airport.id = city_route.origin_airport_id
    JOIN public.airports destination_airport
      ON destination_airport.id = city_route.destination_airport_id
    JOIN public.airlines operating_airline
      ON operating_airline.id = city_route.operating_airline_id
    JOIN public.countries destination_country
      ON destination_country.id = city_route.destination_country_id
    JOIN public.cities destination_city
      ON destination_city.id = city_route.destination_city_id
    WHERE city_route.origin_city_id = v_city_id
      AND city_route.data_version = v_data_version
      AND (
        cardinality(v_origin_airports) = 0
        OR origin_airport.iata = ANY(v_origin_airports)
      )
      AND (
        cardinality(v_airlines) = 0
        OR operating_airline.iata = ANY(v_airlines)
      )
      AND (
        cardinality(v_destination_countries) = 0
        OR destination_country.iso2 = ANY(v_destination_countries)
      )
      AND (
        v_max_duration_minutes IS NULL
        OR city_route.shortest_duration_minutes <= v_max_duration_minutes
      )
      AND (
        v_departure_window IS NULL
        OR (
          v_departure_window = 'morning'
          AND city_route.earliest_departure_time >= TIME '05:00'
          AND city_route.earliest_departure_time < TIME '12:00'
        )
        OR (
          v_departure_window = 'afternoon'
          AND city_route.earliest_departure_time >= TIME '12:00'
          AND city_route.earliest_departure_time < TIME '17:00'
        )
        OR (
          v_departure_window = 'evening'
          AND city_route.earliest_departure_time >= TIME '17:00'
          AND city_route.earliest_departure_time < TIME '21:00'
        )
        OR (
          v_departure_window = 'night'
          AND (
            city_route.earliest_departure_time >= TIME '21:00'
            OR city_route.earliest_departure_time < TIME '05:00'
          )
        )
      )
  ),
  destinations AS (
    SELECT
      filtered.destination_city_id,
      filtered.destination_city_name,
      filtered.destination_city_slug,
      filtered.destination_country_iso2,
      filtered.destination_country_name,
      jsonb_agg(
        DISTINCT filtered.origin_airport_iata
        ORDER BY filtered.origin_airport_iata
      ) AS origin_airports,
      jsonb_agg(
        DISTINCT filtered.destination_airport_iata
        ORDER BY filtered.destination_airport_iata
      ) AS destination_airports,
      jsonb_agg(
        DISTINCT filtered.operating_airline_iata
        ORDER BY filtered.operating_airline_iata
      ) AS airlines,
      count(*) AS direct_route_count,
      CASE
        WHEN count(filtered.frequency_per_week) = 0 THEN NULL
        ELSE sum(filtered.frequency_per_week)
      END AS frequency_per_week,
      min(filtered.shortest_duration_minutes) AS shortest_duration_minutes,
      max(filtered.longest_duration_minutes) AS longest_duration_minutes,
      min(filtered.confidence_score) AS confidence_score
    FROM filtered
    GROUP BY
      filtered.destination_city_id,
      filtered.destination_city_name,
      filtered.destination_city_slug,
      filtered.destination_country_iso2,
      filtered.destination_country_name
  ),
  page AS (
    SELECT destinations.*
    FROM destinations
    ORDER BY
      COALESCE(destinations.frequency_per_week, 0) DESC,
      destinations.shortest_duration_minutes,
      destinations.confidence_score DESC,
      destinations.destination_city_name
    LIMIT v_limit
    OFFSET v_offset
  )
  SELECT jsonb_build_object(
    'data', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'city', jsonb_build_object(
            'name', page.destination_city_name,
            'slug', page.destination_city_slug
          ),
          'country', jsonb_build_object(
            'iso2', page.destination_country_iso2,
            'name', page.destination_country_name
          ),
          'origin_airports', page.origin_airports,
          'destination_airports', page.destination_airports,
          'airlines', page.airlines,
          'direct_route_count', page.direct_route_count,
          'frequency_per_week', page.frequency_per_week,
          'shortest_duration_minutes', page.shortest_duration_minutes,
          'longest_duration_minutes', page.longest_duration_minutes,
          'confidence_score', page.confidence_score,
          'route_path', format(
            '/flights/%s-to-%s',
            v_city_slug,
            page.destination_city_slug
          )
        )
        ORDER BY
          COALESCE(page.frequency_per_week, 0) DESC,
          page.shortest_duration_minutes,
          page.confidence_score DESC,
          page.destination_city_name
      )
      FROM page
    ), '[]'::JSONB),
    'meta', jsonb_build_object(
      'total', (SELECT count(*) FROM destinations),
      'limit', v_limit,
      'offset', v_offset,
      'data_version', v_data_version,
      'facets', jsonb_build_object(
        'airports', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'value', airport_facet.origin_airport_iata,
              'count', airport_facet.destination_count
            )
            ORDER BY airport_facet.origin_airport_iata
          )
          FROM (
            SELECT
              filtered.origin_airport_iata,
              count(DISTINCT filtered.destination_city_id) AS destination_count
            FROM filtered
            GROUP BY filtered.origin_airport_iata
          ) airport_facet
        ), '[]'::JSONB),
        'airlines', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'value', airline_facet.operating_airline_iata,
              'label', airline_facet.operating_airline_name,
              'count', airline_facet.destination_count
            )
            ORDER BY airline_facet.operating_airline_iata
          )
          FROM (
            SELECT
              filtered.operating_airline_iata,
              filtered.operating_airline_name,
              count(DISTINCT filtered.destination_city_id) AS destination_count
            FROM filtered
            GROUP BY
              filtered.operating_airline_iata,
              filtered.operating_airline_name
          ) airline_facet
        ), '[]'::JSONB),
        'countries', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'value', country_facet.destination_country_iso2,
              'label', country_facet.destination_country_name,
              'count', country_facet.destination_count
            )
            ORDER BY country_facet.destination_country_name
          )
          FROM (
            SELECT
              filtered.destination_country_iso2,
              filtered.destination_country_name,
              count(DISTINCT filtered.destination_city_id) AS destination_count
            FROM filtered
            GROUP BY
              filtered.destination_country_iso2,
              filtered.destination_country_name
          ) country_facet
        ), '[]'::JSONB)
      )
    ),
    'error', NULL
  )
  INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_city_direct_routes(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_search_city_direct_routes(JSONB) TO service_role;
