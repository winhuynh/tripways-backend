-- ============================================================================
-- Table: admin.route_price_cache_leases
-- Purpose: Coordinate on-demand price cache refreshes, prevent thundering herd,
--          and track cooldowns for empty or failed responses.
-- ============================================================================

CREATE TABLE admin.route_price_cache_leases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_iata CHAR(3) NOT NULL,
  destination_iata CHAR(3) NULL,
  market_code VARCHAR(2) NOT NULL DEFAULT 'us',
  currency_code VARCHAR(3) NOT NULL DEFAULT 'USD',
  status VARCHAR(20) NOT NULL DEFAULT 'idle' CHECK (status IN ('idle', 'refreshing', 'fresh', 'empty', 'failed')),
  lease_expires_at TIMESTAMPTZ NULL,
  last_attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_succeeded_at TIMESTAMPTZ NULL,
  next_allowed_refresh_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  failure_code VARCHAR(50) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_route_price_cache_scope UNIQUE (origin_iata, destination_iata, market_code, currency_code)
);

CREATE INDEX idx_route_price_cache_leases_lookup
  ON admin.route_price_cache_leases (origin_iata, destination_iata, next_allowed_refresh_at);

REVOKE ALL ON TABLE admin.route_price_cache_leases FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.route_price_cache_leases TO service_role;
