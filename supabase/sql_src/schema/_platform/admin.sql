-- Schema: admin
-- Purpose: Operational state for ingestion, publishing, and maintenance workflows.

CREATE SCHEMA IF NOT EXISTS admin;

REVOKE ALL ON SCHEMA admin FROM anon, authenticated;
GRANT USAGE ON SCHEMA admin TO service_role;
