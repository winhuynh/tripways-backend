-- ============================================================================
-- Function: public.rpc_purge_expired_direct_flight_routes
-- Purpose: Public RPC wrapper for worker services to purge expired cached routes.
-- Responsibilities: Forward call to admin purge function, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_purge_expired_direct_flight_routes(
  p_source_code TEXT,
  p_retention_interval TEXT DEFAULT '7 days'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_interval INTERVAL;
BEGIN
  BEGIN
    v_interval := pg_catalog.coalesce(pg_catalog.nullif(p_retention_interval, '')::INTERVAL, '7 days'::INTERVAL);
  EXCEPTION WHEN OTHERS THEN
    v_interval := '7 days'::INTERVAL;
  END;

  RETURN admin.purge_expired_direct_flight_routes(p_source_code, v_interval);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_purge_expired_direct_flight_routes(TEXT, TEXT)
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_purge_expired_direct_flight_routes(TEXT, TEXT) TO service_role;
