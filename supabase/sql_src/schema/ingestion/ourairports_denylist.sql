-- Table: admin.ourairports_denylist
-- Feature: OurAirports Ingestion
-- Purpose: Exclude IATA airports that do not fit Tripways commercial coverage.
-- Responsibilities: Keep reviewed exclusions auditable and outside provider adapter code.

CREATE TABLE admin.ourairports_denylist (
  iata        TEXT         PRIMARY KEY,
  reason      TEXT         NOT NULL,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ourairports_denylist_iata_check
    CHECK (iata ~ '^[A-Z]{3}$'),

  CONSTRAINT ourairports_denylist_reason_check
    CHECK (reason = btrim(reason) AND char_length(reason) BETWEEN 1 AND 240)
);

REVOKE ALL ON TABLE admin.ourairports_denylist FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.ourairports_denylist TO service_role;
