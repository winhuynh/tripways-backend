-- Schema: analytics
-- Purpose: Internal product and operational events written through controlled backend boundaries.

CREATE SCHEMA IF NOT EXISTS analytics;

REVOKE ALL ON SCHEMA analytics FROM anon, authenticated;

