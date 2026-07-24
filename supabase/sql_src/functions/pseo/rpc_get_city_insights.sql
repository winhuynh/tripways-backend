-- ============================================================================
-- Function: public.rpc_get_city_insights
-- Feature: Interactive pSEO
-- Purpose: Return factual city-level direct-flight insights.
-- Responsibilities: Derive bounded facts from the current published route projection.
-- Notes: Unknown frequency-based facts remain NULL.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_city_insights(p_input JSONB)
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
  v_quick_facts JSONB;
  v_result JSONB;
BEGIN
  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error('null'::JSONB, v_identity #>> '{error,code}', v_identity #>> '{error,message}');
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';
  v_context := private.resolve_city_page_context(v_city_slug, v_locale);

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error('null'::JSONB, v_context #>> '{error,code}', v_context #>> '{error,message}');
  END IF;

  v_city_id := (v_context #>> '{data,city_id}')::UUID;
  v_data_version := (v_context #>> '{data,data_version}')::UUID;
  v_quick_facts := private.get_city_quick_facts(
    v_city_id,
    v_data_version
  );

  WITH routes AS MATERIALIZED (
    SELECT city_route.*
    FROM public.city_direct_routes city_route
    WHERE city_route.origin_city_id = v_city_id
      AND city_route.data_version = v_data_version
  ),
  destination_frequency AS (
    SELECT
      route.destination_city_id,
      sum(route.frequency_per_week) AS frequency_per_week
    FROM routes route
    WHERE route.frequency_per_week IS NOT NULL
    GROUP BY route.destination_city_id
    ORDER BY sum(route.frequency_per_week) DESC, route.destination_city_id
    LIMIT 1
  ),
  airline_frequency AS (
    SELECT
      route.operating_airline_id,
      sum(route.frequency_per_week) AS frequency_per_week
    FROM routes route
    WHERE route.frequency_per_week IS NOT NULL
    GROUP BY route.operating_airline_id
    ORDER BY sum(route.frequency_per_week) DESC, route.operating_airline_id
    LIMIT 1
  )
  SELECT jsonb_build_object(
    'data', jsonb_build_object(
      'most_popular_destination', (
        SELECT destination_city.name
        FROM destination_frequency
        JOIN public.cities destination_city
          ON destination_city.id = destination_frequency.destination_city_id
      ),
      'shortest_destination', v_quick_facts #>> '{shortest_route,destination_name}',
      'longest_destination', v_quick_facts #>> '{longest_route,destination_name}',
      'top_airline', (
        SELECT airline.name
        FROM airline_frequency
        JOIN public.airlines airline
          ON airline.id = airline_frequency.operating_airline_id
      ),
      'average_duration_minutes', (
        SELECT round(avg(route.shortest_duration_minutes))::INTEGER
        FROM routes route
      ),
      'direct_country_count', (v_quick_facts ->> 'direct_country_count')::INTEGER
    ),
    'meta', jsonb_build_object('data_version', v_data_version),
    'error', NULL
  )
  INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_city_insights(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_city_insights(JSONB) TO service_role;
