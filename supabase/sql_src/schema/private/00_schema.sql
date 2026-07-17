-- Schema: private
-- Purpose: Raw provider data and internal staging records that must never be exposed by Data API.

CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM anon, authenticated;

