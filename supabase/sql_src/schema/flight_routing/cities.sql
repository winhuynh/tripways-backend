-- Table: public.cities
-- Feature: Flight Routing
-- Purpose: Group airports by a normalized city identity.
-- Responsibilities: Link cities to countries and preserve optional geographic metadata.

CREATE TABLE public.cities (
  id          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id  UUID              NOT NULL REFERENCES public.countries (id),
  name        TEXT              NOT NULL,
  slug        TEXT              NOT NULL,
  iata_code   TEXT              NULL UNIQUE,
  currency_code TEXT            NULL,
  primary_language TEXT         NULL,
  latitude    DOUBLE PRECISION  NULL,
  longitude   DOUBLE PRECISION  NULL,
  timezone    TEXT              NULL,
  source_id   UUID              NOT NULL REFERENCES admin.data_sources (id),
  source_record_id TEXT         NOT NULL,
  created_at  TIMESTAMPTZ       NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ       NOT NULL DEFAULT now(),

  CONSTRAINT cities_source_record_key
    UNIQUE (source_id, source_record_id),

  CONSTRAINT cities_country_slug_key
    UNIQUE (country_id, slug),

  CONSTRAINT cities_name_trimmed_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 120),

  CONSTRAINT cities_slug_check
    CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

  CONSTRAINT cities_iata_code_check
    CHECK (iata_code IS NULL OR iata_code ~ '^[A-Z]{3}$'),

  CONSTRAINT cities_currency_code_check
    CHECK (currency_code IS NULL OR currency_code ~ '^[A-Z]{3}$'),

  CONSTRAINT cities_primary_language_check
    CHECK (primary_language IS NULL OR primary_language ~ '^[a-z]{2,3}(?:-[A-Z]{2})?$'),

  CONSTRAINT cities_latitude_check
    CHECK (latitude BETWEEN -90 AND 90),

  CONSTRAINT cities_longitude_check
    CHECK (longitude BETWEEN -180 AND 180),

  CONSTRAINT cities_coordinates_pair_check
    CHECK ((latitude IS NULL) = (longitude IS NULL))
);

CREATE INDEX cities_country_id_idx
ON public.cities USING btree (country_id);

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.cities FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cities TO service_role;
