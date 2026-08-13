-- ============================================================================
-- Function: public.rpc_get_homepage_statistics
-- Purpose: Return current canonical route coverage for the product homepage.
-- Responsibilities: Aggregate bounded data points directly from the current publication.
-- Notes: Homepage copy and layout remain frontend-owned.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_homepage_statistics()
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'data', jsonb_build_object(
      'origin_city_count', count(DISTINCT option.origin_city_id)::INTEGER,
      'origin_airport_count', count(DISTINCT option.origin_airport_id)::INTEGER,
      'published_direct_route_count', count(DISTINCT option.route_path)::INTEGER
    ),
    'meta', jsonb_build_object(
      'data_version', 'v_' || md5(version.id::TEXT),
      'generated_at', version.published_at
    ),
    'error', NULL
  )
  FROM public.publication_versions AS version
  LEFT JOIN public.flight_route_options AS option
    ON option.publication_version_id = version.id
  WHERE version.is_current = TRUE
    AND version.status = 'published'
  GROUP BY version.id, version.published_at;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_homepage_statistics()
FROM public;
GRANT EXECUTE ON FUNCTION public.rpc_get_homepage_statistics()
TO anon, authenticated, service_role;
