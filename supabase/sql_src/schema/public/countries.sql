-- Table: public.countries
-- Feature: Flight Routing
-- Purpose: Provide normalized country identity for cities, airports, and airlines.
-- Responsibilities: Enforce ISO codes, stable slugs, and source lineage.

CREATE TABLE public.countries (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  iso2        TEXT         NOT NULL UNIQUE,
  iso3        TEXT         NOT NULL UNIQUE,
  name        TEXT         NOT NULL,
  slug        TEXT         NOT NULL UNIQUE,
  region      TEXT         NULL,
  subregion   TEXT         NULL,
  source_id   UUID         NOT NULL REFERENCES admin.data_sources (id),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT countries_iso2_check
    CHECK (iso2 ~ '^[A-Z]{2}$'),

  CONSTRAINT countries_iso3_check
    CHECK (iso3 ~ '^[A-Z]{3}$'),

  CONSTRAINT countries_name_trimmed_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 120),

  CONSTRAINT countries_slug_check
    CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

ALTER TABLE public.countries ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.countries FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.countries TO service_role;

