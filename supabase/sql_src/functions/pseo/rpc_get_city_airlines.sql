-- ============================================================================
-- Function: public.rpc_get_city_airlines
-- Feature: Interactive pSEO
-- Purpose: Return airlines operating direct routes from one city.
-- Responsibilities: Aggregate served airports and destinations for the current page version.
-- Notes: Results contain discovery facts, not live schedules or fares.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_city_airlines(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_identity JSONB := private.parse_city_page_identity(p_input);
  v_context JSONB;
  v_city_slug TEXT;
  v_locale TEXT;
  v_city_id UUID;
  v_data_version UUID;
  v_result JSONB;
BEGIN
  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error('[]'::JSONB, v_identity #>> '{error,code}', v_identity #>> '{error,message}');
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';
  v_context := private.resolve_city_page_context(v_city_slug, v_locale);

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error('[]'::JSONB, v_context #>> '{error,code}', v_context #>> '{error,message}');
  END IF;

  v_city_id := (v_context #>> '{data,city_id}')::UUID;
  v_data_version := (v_context #>> '{data,data_version}')::UUID;

  SELECT jsonb_build_object(
    'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'iata', summary.iata,
        'icao', summary.icao,
        'name', summary.name,
        'slug', summary.slug,
        'origin_airports', summary.origin_airports,
        'direct_counterpart_city_count', summary.direct_counterpart_city_count,
        'page_path', format('/airlines/%s/flights-from/%s', summary.slug, v_city_slug)
      )
      ORDER BY summary.direct_counterpart_city_count DESC, summary.name
    ), '[]'::JSONB),
    'meta', jsonb_build_object('data_version', v_data_version),
    'error', NULL
  )
  INTO v_result
  FROM (
    SELECT
      airline.iata,
      airline.icao,
      airline.name,
      airline.slug,
      jsonb_agg(DISTINCT origin_airport.iata ORDER BY origin_airport.iata) AS origin_airports,
      count(DISTINCT city_route.destination_city_id) AS direct_counterpart_city_count
    FROM public.pseo_direct_routes city_route
    JOIN public.airlines airline
      ON airline.id = city_route.operating_airline_id
    JOIN public.airports origin_airport
      ON origin_airport.id = city_route.origin_airport_id
    WHERE city_route.origin_city_id = v_city_id
      AND city_route.data_version = v_data_version
    GROUP BY airline.id
  ) summary;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_city_airlines(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_city_airlines(JSONB) TO service_role;
