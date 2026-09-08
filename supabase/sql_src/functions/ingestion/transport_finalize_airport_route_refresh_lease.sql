-- ============================================================================
-- Function: public.rpc_finalize_airport_route_refresh_lease
-- Purpose: PostgREST transport wrapper for airport route refresh lease finalization.
-- Responsibilities: Forward request to internal admin function, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_finalize_airport_route_refresh_lease(
  p_origin_iata TEXT,
  p_status TEXT,
  p_failure_code TEXT DEFAULT NULL,
  p_lease_token UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.rpc_finalize_airport_route_refresh_lease(p_origin_iata, p_status, p_failure_code, p_lease_token);
$$;

REVOKE ALL ON FUNCTION public.rpc_finalize_airport_route_refresh_lease(TEXT, TEXT, TEXT, UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_finalize_airport_route_refresh_lease(TEXT, TEXT, TEXT, UUID) TO service_role;
