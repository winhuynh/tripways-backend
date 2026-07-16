-- Schema: admin
-- Purpose: Operational state for ingestion, publishing, and maintenance workflows.

create schema if not exists admin;

revoke all on schema admin from anon, authenticated;

