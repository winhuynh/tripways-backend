-- ============================================================================
-- Function: public.rpc_get_ourairports_denylist
-- Purpose: Return reviewed OurAirports exclusions to the privileged ingestion worker.
-- Responsibilities: Keep the admin table unavailable to public API roles.
-- Notes: This security-invoker wrapper is executable only by service_role.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_ourairports_denylist()
RETURNS TEXT[]
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT COALESCE(array_agg(entry.iata ORDER BY entry.iata), '{}'::TEXT[])
  FROM admin.ourairports_denylist AS entry;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_ourairports_denylist()
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_get_ourairports_denylist() TO service_role;
