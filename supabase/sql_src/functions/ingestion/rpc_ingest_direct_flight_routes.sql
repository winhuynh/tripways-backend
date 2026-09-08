-- ============================================================================
-- Function: public.rpc_ingest_direct_flight_routes
-- Purpose: PostgREST transport wrapper for direct flight route ingestion.
-- Responsibilities: Forward batch to internal admin function, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_ingest_direct_flight_routes(
  p_source_code TEXT,
  p_routes      JSONB,
  p_origin_iata TEXT DEFAULT NULL,
  p_lease_token UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.ingest_direct_flight_routes_batch(p_source_code, p_routes, p_origin_iata, p_lease_token);
$$;

REVOKE ALL ON FUNCTION public.rpc_ingest_direct_flight_routes(TEXT, JSONB, TEXT, UUID)
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_ingest_direct_flight_routes(TEXT, JSONB, TEXT, UUID) TO service_role;
