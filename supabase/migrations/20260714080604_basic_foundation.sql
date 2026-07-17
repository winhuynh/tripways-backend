-- Source: supabase/sql_src/schema/private/00_schema.sql
-- Schema: private
-- Purpose: Raw provider data and internal staging records that must never be exposed by Data API.

CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM anon, authenticated;

-- Source: supabase/sql_src/schema/admin/00_schema.sql
-- Schema: admin
-- Purpose: Operational state for ingestion, publishing, and maintenance workflows.

CREATE SCHEMA IF NOT EXISTS admin;

REVOKE ALL ON SCHEMA admin FROM anon, authenticated;

-- Source: supabase/sql_src/schema/analytics/00_schema.sql
-- Schema: analytics
-- Purpose: Internal product and operational events written through controlled backend boundaries.

CREATE SCHEMA IF NOT EXISTS analytics;

REVOKE ALL ON SCHEMA analytics FROM anon, authenticated;

-- Source: supabase/sql_src/functions/system/health_check.sql
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
