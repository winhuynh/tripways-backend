-- ============================================================================
-- Function: private.get_city_quick_facts
-- Feature: Interactive pSEO
-- Purpose: Derive one version-consistent city Quick Facts read model.
-- Responsibilities: Count city coverage and resolve shortest and longest direct destinations.
-- Notes: Route extrema use stored recurring schedules, not live dated availability.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.get_city_quick_facts(
  p_city_id UUID,
  p_data_version UUID
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  WITH city_context AS (
    SELECT
      city.id,
      city.slug
    FROM public.cities city
    WHERE city.id = p_city_id
  ),
  routes AS MATERIALIZED (
    SELECT city_route.*
    FROM public.pseo_direct_routes city_route
    WHERE city_route.origin_city_id = p_city_id
      AND city_route.data_version = p_data_version
  ),
  route_counts AS (
    SELECT
      count(DISTINCT route.destination_city_id)::INTEGER AS direct_counterpart_city_count,
      count(DISTINCT route.destination_country_id)::INTEGER AS direct_counterpart_country_count,
      count(DISTINCT route.operating_airline_id)::INTEGER AS airline_count
    FROM routes route
  ),
  shortest_route AS (
    SELECT jsonb_build_object(
      'destination_name', destination_city.name,
      'destination_slug', destination_city.slug,
      'route_path', format(
        '/flights/%s-to-%s',
        city_context.slug,
        destination_city.slug
      ),
      'duration_minutes', route.shortest_duration_minutes
    ) AS value
    FROM routes route
    CROSS JOIN city_context
    JOIN public.cities destination_city
      ON destination_city.id = route.destination_city_id
    ORDER BY
      route.shortest_duration_minutes,
      destination_city.name
    LIMIT 1
  ),
  longest_route AS (
    SELECT jsonb_build_object(
      'destination_name', destination_city.name,
      'destination_slug', destination_city.slug,
      'route_path', format(
        '/flights/%s-to-%s',
        city_context.slug,
        destination_city.slug
      ),
      'duration_minutes', route.longest_duration_minutes
    ) AS value
    FROM routes route
    CROSS JOIN city_context
    JOIN public.cities destination_city
      ON destination_city.id = route.destination_city_id
    ORDER BY
      route.longest_duration_minutes DESC,
      destination_city.name
    LIMIT 1
  )
  SELECT jsonb_build_object(
    'airport_count', (
      SELECT count(*)::INTEGER
      FROM public.airports airport
      WHERE airport.city_id = p_city_id
        AND airport.status = 'active'
    ),
    'direct_counterpart_city_count', route_counts.direct_counterpart_city_count,
    'direct_counterpart_country_count', route_counts.direct_counterpart_country_count,
    'airline_count', route_counts.airline_count,
    'shortest_route', (
      SELECT shortest_route.value
      FROM shortest_route
    ),
    'longest_route', (
      SELECT longest_route.value
      FROM longest_route
    )
  )
  FROM route_counts;
$$;

REVOKE ALL ON FUNCTION private.get_city_quick_facts(UUID, UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.get_city_quick_facts(UUID, UUID) TO service_role;
