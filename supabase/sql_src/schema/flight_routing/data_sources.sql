-- Table: admin.data_sources
-- Feature: Flight Routing
-- Purpose: Record data provenance and permitted usage before domain data is published.
-- Responsibilities: Identify sources, separate environments, and preserve license capabilities.

CREATE TABLE admin.data_sources (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  TEXT         NOT NULL UNIQUE,
  provider_code         TEXT         NOT NULL DEFAULT 'internal',
  name                  TEXT         NOT NULL,
  source_type           TEXT         NOT NULL,
  environment_scope     TEXT         NOT NULL,
  production_allowed    BOOLEAN      NOT NULL DEFAULT FALSE,
  seo_allowed           BOOLEAN      NOT NULL DEFAULT FALSE,
  derived_data_allowed  BOOLEAN      NOT NULL DEFAULT FALSE,
  storage_allowed       BOOLEAN      NOT NULL DEFAULT FALSE,
  retention_days        INTEGER      NULL,
  production_display_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  cache_allowed         BOOLEAN      NOT NULL DEFAULT FALSE,
  max_cache_ttl_seconds INTEGER      NULL,
  attribution_text      TEXT         NULL,
  attribution_url       TEXT         NULL,
  rights_effective_at   TIMESTAMPTZ  NULL,
  rights_expires_at     TIMESTAMPTZ  NULL,
  license_notes         TEXT         NULL,
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT data_sources_code_check
    CHECK (code ~ '^[a-z0-9]+(?:[_-][a-z0-9]+)*$'),

  CONSTRAINT data_sources_provider_code_key
    UNIQUE (provider_code, code),

  CONSTRAINT data_sources_provider_code_check
    CHECK (provider_code ~ '^[a-z0-9]+(?:[_-][a-z0-9]+)*$'),

  CONSTRAINT data_sources_name_trimmed_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 120),

  CONSTRAINT data_sources_type_check
    CHECK (source_type IN ('base_data', 'content_observation', 'schedule', 'development_fixture')),

  CONSTRAINT data_sources_environment_check
    CHECK (environment_scope IN ('development', 'production')),

  CONSTRAINT data_sources_retention_check
    CHECK (
      (storage_allowed = FALSE AND retention_days IS NULL)
      OR (storage_allowed = TRUE AND retention_days > 0)
    ),

  CONSTRAINT data_sources_cache_check
    CHECK (
      (cache_allowed = FALSE AND max_cache_ttl_seconds IS NULL)
      OR (cache_allowed = TRUE AND max_cache_ttl_seconds > 0)
    ),

  CONSTRAINT data_sources_attribution_check
    CHECK (
      (attribution_text IS NULL) = (attribution_url IS NULL)
      AND (
        attribution_url IS NULL
        OR attribution_url ~ '^https://'
      )
    ),

  CONSTRAINT data_sources_rights_window_check
    CHECK (
      (rights_effective_at IS NULL) = (rights_expires_at IS NULL)
      AND (
        rights_effective_at IS NULL
        OR rights_effective_at < rights_expires_at
      )
    ),

  CONSTRAINT data_sources_development_rights_check
    CHECK (
      environment_scope = 'production'
      OR (
        production_allowed = FALSE
        AND production_display_allowed = FALSE
        AND seo_allowed = FALSE
      )
    )
);

REVOKE ALL ON TABLE admin.data_sources FROM public, anon, authenticated;
GRANT USAGE ON SCHEMA admin TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.data_sources TO service_role;
