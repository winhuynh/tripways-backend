-- Table: public.metro_areas
-- Feature: Place Discovery
-- Purpose: Group airports under a stable multi-airport market identity.

CREATE TABLE public.metro_areas (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id        UUID         NOT NULL REFERENCES public.countries (id),
  city_id           UUID         NULL REFERENCES public.cities (id),
  code              TEXT         NOT NULL UNIQUE,
  name              TEXT         NOT NULL,
  slug              TEXT         NOT NULL UNIQUE,
  source_id         UUID         NOT NULL REFERENCES admin.data_sources (id),
  source_record_id  TEXT         NOT NULL,
  last_verified_at  TIMESTAMPTZ  NOT NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT metro_areas_source_record_key UNIQUE (source_id, source_record_id),
  CONSTRAINT metro_areas_code_check CHECK (code ~ '^[A-Z]{3}$'),
  CONSTRAINT metro_areas_slug_check CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

ALTER TABLE public.metro_areas ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.metro_areas FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.metro_areas TO service_role;

