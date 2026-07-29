-- ============================================================================
-- Function: public.rpc_get_city_airports
-- Feature: Interactive pSEO
-- Purpose: Return active airport hubs for one city page.
-- Responsibilities: Compose airport facts, reviewed copy, and reusable versioned route statistics.
-- Notes: Airport pages are semantic children of the city page.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_city_airports(p_input JSONB)
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
  v_route_direction TEXT;
  v_city_id UUID;
  v_city_page_id UUID;
  v_data_version UUID;
  v_result JSONB;
BEGIN
  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error('[]'::JSONB, v_identity #>> '{error,code}', v_identity #>> '{error,message}');
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';
  v_route_direction := v_identity #>> '{data,route_direction}';
  v_context := private.resolve_city_page_context(
    v_city_slug,
    v_locale,
    v_route_direction
  );

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error('[]'::JSONB, v_context #>> '{error,code}', v_context #>> '{error,message}');
  END IF;

  v_city_id := (v_context #>> '{data,city_id}')::UUID;
  v_city_page_id := (v_context #>> '{data,city_page_id}')::UUID;
  v_data_version := (v_context #>> '{data,data_version}')::UUID;

  SELECT jsonb_build_object(
    'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'iata', airport.iata,
        'icao', airport.icao,
        'name', airport.name,
        'slug', airport.slug,
        'airport_type', airport.airport_type,
        'latitude', airport.latitude,
        'longitude', airport.longitude,
        'timezone', airport.timezone,
        'is_primary', airport.id = city_page.primary_airport_id,
        'hub_label', airport_content.hub_label,
        'description', airport_content.description,
        'display_order', airport_content.display_order,
        'direct_counterpart_city_count', airport_stats.direct_counterpart_city_count,
        'domestic_destination_count', airport_stats.domestic_destination_count,
        'international_destination_count', airport_stats.international_destination_count,
        'domestic_destination_percentage', airport_stats.domestic_destination_percentage,
        'international_destination_percentage', airport_stats.international_destination_percentage,
        'airline_count', airport_stats.airline_count,
        'dominant_airline_business_model', airport_stats.dominant_airline_business_model,
        'page_path', format('/flights-from/%s/%s', v_city_slug, lower(airport.iata))
      )
      ORDER BY
        airport_content.display_order NULLS LAST,
        (airport.id = city_page.primary_airport_id) DESC,
        airport.iata
    ), '[]'::JSONB),
    'meta', jsonb_build_object(
      'city_slug', v_city_slug,
      'locale', v_locale,
      'data_version', v_data_version
    ),
    'error', NULL
  )
  INTO v_result
  FROM public.airports airport
  JOIN public.city_pages city_page
    ON city_page.id = v_city_page_id
  JOIN private.get_city_airport_route_stats(
    v_city_id,
    v_data_version
  ) airport_stats
    ON airport_stats.airport_id = airport.id
  LEFT JOIN public.city_page_airport_content airport_content
    ON airport_content.city_page_id = city_page.id
    AND airport_content.airport_id = airport.id
    AND airport_content.status = 'published'
  WHERE airport.city_id = v_city_id
    AND airport.status = 'active';

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_city_airports(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_city_airports(JSONB) TO service_role;
