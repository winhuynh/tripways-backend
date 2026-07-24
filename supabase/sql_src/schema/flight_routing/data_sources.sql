-- Table: admin.data_sources
-- Feature: Flight Routing
-- Purpose: Record data provenance and permitted usage before domain data is published.
-- Responsibilities: Identify sources, separate environments, and preserve license capabilities.

CREATE TABLE admin.data_sources (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  TEXT         NOT NULL UNIQUE,
  name                  TEXT         NOT NULL,
  source_type           TEXT         NOT NULL,
  environment_scope     TEXT         NOT NULL,
  production_allowed    BOOLEAN      NOT NULL DEFAULT FALSE,
  seo_allowed           BOOLEAN      NOT NULL DEFAULT FALSE,
  derived_data_allowed  BOOLEAN      NOT NULL DEFAULT FALSE,
  license_notes         TEXT         NULL,
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT data_sources_code_check
    CHECK (code ~ '^[a-z0-9]+(?:[_-][a-z0-9]+)*$'),

  CONSTRAINT data_sources_name_trimmed_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 120),

  CONSTRAINT data_sources_type_check
    CHECK (source_type IN ('base_data', 'schedule', 'development_fixture')),

  CONSTRAINT data_sources_environment_check
    CHECK (environment_scope IN ('development', 'production')),

  CONSTRAINT data_sources_development_rights_check
    CHECK (
      environment_scope = 'production'
      OR (production_allowed = FALSE AND seo_allowed = FALSE)
    )
);

REVOKE ALL ON TABLE admin.data_sources FROM public, anon, authenticated;
GRANT USAGE ON SCHEMA admin TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.data_sources TO service_role;

