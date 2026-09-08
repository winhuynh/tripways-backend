-- ============================================================================
-- Function: public.rpc_get_top_routes_to_warm
-- Purpose: PostgREST transport wrapper for top routes to warm.
-- Responsibilities: Forward call to internal admin implementation, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_top_routes_to_warm(
  p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.rpc_get_top_routes_to_warm(p_limit);
$$;

REVOKE ALL ON FUNCTION public.rpc_get_top_routes_to_warm(INTEGER) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_top_routes_to_warm(INTEGER) TO service_role;
