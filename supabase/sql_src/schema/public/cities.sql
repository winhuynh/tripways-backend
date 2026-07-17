-- Table: public.cities
-- Feature: Flight Routing
-- Purpose: Group airports by a normalized city identity.
-- Responsibilities: Link cities to countries and preserve optional geographic metadata.

CREATE TABLE public.cities (
  id          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id  UUID              NOT NULL REFERENCES public.countries (id),
  name        TEXT              NOT NULL,
  slug        TEXT              NOT NULL,
  latitude    DOUBLE PRECISION  NULL,
  longitude   DOUBLE PRECISION  NULL,
  timezone    TEXT              NULL,
  source_id   UUID              NOT NULL REFERENCES admin.data_sources (id),
  created_at  TIMESTAMPTZ       NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ       NOT NULL DEFAULT now(),

  CONSTRAINT cities_country_slug_key
    UNIQUE (country_id, slug),

  CONSTRAINT cities_name_trimmed_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 120),

  CONSTRAINT cities_slug_check
    CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

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
