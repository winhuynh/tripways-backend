-- Table: admin.flight_route_cache_states
-- Feature: On-demand Flight Route Cache
-- Purpose: Coordinate demand, leases, freshness, and cooldown without storing provider payloads.

CREATE TABLE admin.flight_route_cache_states (
  cache_key              TEXT        PRIMARY KEY,
  origin_iata            TEXT        NOT NULL,
  destination_iata       TEXT        NULL,
  market_code            TEXT        NOT NULL,
  currency_code          TEXT        NOT NULL,
  locale                 TEXT        NOT NULL,
  status                 TEXT        NOT NULL DEFAULT 'idle',
  lease_token            TEXT        NULL,
  lease_expires_at       TIMESTAMPTZ NULL,
  next_refresh_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_requested_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_attempted_at      TIMESTAMPTZ NULL,
  last_succeeded_at      TIMESTAMPTZ NULL,
  refreshed_at           TIMESTAMPTZ NULL,
  valid_until            TIMESTAMPTZ NULL,
  observation_count      INTEGER     NOT NULL DEFAULT 0,
  consecutive_failures   INTEGER     NOT NULL DEFAULT 0,
  failure_code           TEXT        NULL,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT flight_route_cache_states_key_check
    CHECK (cache_key ~ '^frc_[0-9a-f]{32}$'),

  CONSTRAINT flight_route_cache_states_origin_check
    CHECK (origin_iata ~ '^[A-Z0-9]{3}$'),

  CONSTRAINT flight_route_cache_states_destination_check
    CHECK (destination_iata IS NULL OR destination_iata ~ '^[A-Z0-9]{3}$'),

  CONSTRAINT flight_route_cache_states_direction_check
    CHECK (destination_iata IS NULL OR destination_iata <> origin_iata),

  CONSTRAINT flight_route_cache_states_market_check
    CHECK (market_code ~ '^[a-z]{2}$'),

  CONSTRAINT flight_route_cache_states_currency_check
    CHECK (currency_code ~ '^[A-Z]{3}$'),

  CONSTRAINT flight_route_cache_states_locale_check
    CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

  CONSTRAINT flight_route_cache_states_status_check
    CHECK (status IN ('idle', 'refreshing', 'fresh', 'empty', 'failed')),

  CONSTRAINT flight_route_cache_states_lease_check
    CHECK ((lease_token IS NULL) = (lease_expires_at IS NULL)),

  CONSTRAINT flight_route_cache_states_count_check
    CHECK (observation_count >= 0 AND consecutive_failures >= 0)
);

CREATE INDEX flight_route_cache_states_due_idx
ON admin.flight_route_cache_states USING btree (next_refresh_at, last_requested_at)
WHERE status IN ('fresh', 'empty', 'failed');

CREATE INDEX flight_route_cache_states_lease_idx
ON admin.flight_route_cache_states USING btree (lease_expires_at)
WHERE status = 'refreshing';

ALTER TABLE admin.flight_route_cache_states ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE admin.flight_route_cache_states FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.flight_route_cache_states TO service_role;
