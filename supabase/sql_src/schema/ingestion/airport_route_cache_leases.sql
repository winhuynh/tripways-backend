-- ============================================================================
-- Table: admin.airport_route_cache_leases
-- Purpose: Coordinate on-demand direct route cache refreshes for unfamiliar airports,
--          prevent thundering herd, and track cooldowns for empty or failed responses.
-- ============================================================================

CREATE TABLE admin.airport_route_cache_leases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_iata CHAR(3) NOT NULL UNIQUE,
  status VARCHAR(20) NOT NULL DEFAULT 'idle' CHECK (status IN ('idle', 'refreshing', 'fresh', 'empty', 'failed')),
  lease_token UUID NULL,
  lease_expires_at TIMESTAMPTZ NULL,
  last_attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_succeeded_at TIMESTAMPTZ NULL,
  next_allowed_refresh_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  failure_code VARCHAR(50) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_airport_route_cache_leases_lookup
  ON admin.airport_route_cache_leases (origin_iata, next_allowed_refresh_at);

REVOKE ALL ON TABLE admin.airport_route_cache_leases FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.airport_route_cache_leases TO service_role;
