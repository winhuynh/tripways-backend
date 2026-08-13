-- ============================================================================
-- Function: public.rpc_fail_flight_route_cache_refresh
-- Purpose: Finalize one failed on-demand provider lease with bounded backoff.
-- Responsibilities: Match the opaque lease and preserve existing unexpired observations.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_fail_flight_route_cache_refresh(
  p_lease_token TEXT,
  p_failure_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_cache admin.flight_route_cache_states%ROWTYPE;
BEGIN
  IF p_lease_token !~ '^lease_[0-9a-f]{32}$'
    OR p_failure_code !~ '^ERR_[A-Z0-9_]+$'
  THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST';
  END IF;

  SELECT cache.*
  INTO v_cache
  FROM admin.flight_route_cache_states AS cache
  WHERE cache.lease_token = p_lease_token
  FOR UPDATE;

  IF v_cache.cache_key IS NULL THEN
    RETURN jsonb_build_object('status', 'ignored');
  END IF;

  UPDATE admin.flight_route_cache_states AS cache
  SET
    status = 'failed',
    lease_token = NULL,
    lease_expires_at = NULL,
    consecutive_failures = cache.consecutive_failures + 1,
    failure_code = p_failure_code,
    next_refresh_at = now() + LEAST(
      INTERVAL '6 hours',
      INTERVAL '15 minutes' * power(2, LEAST(cache.consecutive_failures, 4))
    ),
    updated_at = now()
  WHERE cache.cache_key = v_cache.cache_key;

  RETURN jsonb_build_object('status', 'failed');
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_fail_flight_route_cache_refresh(TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_fail_flight_route_cache_refresh(TEXT, TEXT) TO service_role;
