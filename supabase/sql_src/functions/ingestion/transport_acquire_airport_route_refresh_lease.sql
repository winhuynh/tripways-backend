-- ============================================================================
-- Function: public.rpc_acquire_airport_route_refresh_lease
-- Purpose: PostgREST transport wrapper for airport route refresh lease acquisition.
-- Responsibilities: Forward request to internal admin function, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_acquire_airport_route_refresh_lease(
  p_origin_iata TEXT
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.rpc_acquire_airport_route_refresh_lease(p_origin_iata);
$$;

REVOKE ALL ON FUNCTION public.rpc_acquire_airport_route_refresh_lease(TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_acquire_airport_route_refresh_lease(TEXT) TO service_role;
