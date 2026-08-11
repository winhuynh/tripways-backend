-- ============================================================================
-- Function: public.rpc_get_homepage_statistics
-- Purpose: Return bounded coverage statistics for the product homepage.
-- Responsibilities: Aggregate only the current published direct-route projection.
-- Notes: Homepage copy and layout remain frontend-owned.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_homepage_statistics()
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'data', to_jsonb(statistics),
    'meta', jsonb_build_object(
      'data_version', statistics.data_version,
      'generated_at', statistics.generated_at
    ),
    'error', NULL
  )
  FROM public.homepage_statistics statistics;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_homepage_statistics()
FROM public;
GRANT EXECUTE ON FUNCTION public.rpc_get_homepage_statistics()
TO anon, authenticated, service_role;
