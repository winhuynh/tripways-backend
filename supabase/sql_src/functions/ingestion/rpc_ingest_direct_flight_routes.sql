-- ============================================================================
-- Function: public.rpc_ingest_direct_flight_routes
-- Purpose: PostgREST transport wrapper for direct flight route ingestion.
-- Responsibilities: Forward batch to internal admin function, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_ingest_direct_flight_routes(
  p_source_code TEXT,
  p_routes      JSONB
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.ingest_direct_flight_routes_batch(p_source_code, p_routes);
$$;

REVOKE ALL ON FUNCTION public.rpc_ingest_direct_flight_routes(TEXT, JSONB)
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_ingest_direct_flight_routes(TEXT, JSONB) TO service_role;
