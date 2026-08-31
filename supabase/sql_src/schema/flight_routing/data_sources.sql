-- Table: admin.data_sources
-- Feature: Flight Routing
-- Purpose: Record data provenance for canonical flight and geographic entities.
-- Responsibilities: Identify sources simply and reliably.

CREATE TABLE admin.data_sources (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT         NOT NULL UNIQUE,
  name        TEXT         NOT NULL,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT data_sources_code_check
    CHECK (code ~ '^[a-z0-9]+(?:[_-][a-z0-9]+)*$'),

  CONSTRAINT data_sources_name_trimmed_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 120)
);

REVOKE ALL ON TABLE admin.data_sources FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.data_sources TO service_role;

