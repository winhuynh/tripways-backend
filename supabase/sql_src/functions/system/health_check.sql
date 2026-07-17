-- ============================================================================
-- Function: public.health_check
-- Feature: System
-- Purpose: Verify that the database is reachable through a stable, side-effect-free contract.
-- Responsibilities: Return service status and the current database timestamp.
-- Notes: Uses invoker security and reads no domain or private data.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.health_check()
RETURNS TABLE (
  status TEXT,
  checked_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT 'ok'::TEXT, now();
$$;

REVOKE ALL ON FUNCTION public.health_check() FROM public;
GRANT EXECUTE ON FUNCTION public.health_check() TO anon, authenticated, service_role;

