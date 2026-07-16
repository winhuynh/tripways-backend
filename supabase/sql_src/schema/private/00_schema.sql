-- Schema: private
-- Purpose: Raw provider data and internal staging records that must never be exposed by Data API.

create schema if not exists private;

revoke all on schema private from anon, authenticated;

