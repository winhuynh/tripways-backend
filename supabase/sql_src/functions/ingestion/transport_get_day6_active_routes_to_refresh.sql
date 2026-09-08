-- ============================================================================
-- Function: public.rpc_get_day6_active_routes_to_refresh
-- Purpose: PostgREST transport wrapper for day 6 active demand routes refresh.
-- Responsibilities: Forward call to internal admin implementation, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_day6_active_routes_to_refresh(
  p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.rpc_get_day6_active_routes_to_refresh(p_limit);
$$;

REVOKE ALL ON FUNCTION public.rpc_get_day6_active_routes_to_refresh(INTEGER) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_day6_active_routes_to_refresh(INTEGER) TO service_role;
