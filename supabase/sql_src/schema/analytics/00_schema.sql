-- Schema: analytics
-- Purpose: Internal product and operational events written through controlled backend boundaries.

create schema if not exists analytics;

revoke all on schema analytics from anon, authenticated;

