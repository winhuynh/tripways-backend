-- Table: public.airlines
-- Feature: Flight Routing
-- Purpose: Represent airline operators associated with flight routes.
-- Responsibilities: Enforce operator codes, operational state, and source lineage.

CREATE TABLE public.airlines (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  iata              TEXT         NULL,
  icao              TEXT         NULL,
  name              TEXT         NOT NULL,
  slug              TEXT         NOT NULL UNIQUE,
  logo_path         TEXT         NULL,
  country_id        UUID         NULL REFERENCES public.countries (id),
  alliance          TEXT         NULL,
  business_model    TEXT         NOT NULL DEFAULT 'unknown',
  status            TEXT         NOT NULL DEFAULT 'unknown',
  source_id         UUID         NOT NULL REFERENCES admin.data_sources (id),
  source_record_id  TEXT         NOT NULL,
  last_verified_at  TIMESTAMPTZ  NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airlines_source_record_key
    UNIQUE (source_id, source_record_id),

  CONSTRAINT airlines_iata_check
    CHECK (iata IS NULL OR iata ~ '^[A-Z0-9]{2}$'),

  CONSTRAINT airlines_icao_check
    CHECK (icao IS NULL OR icao ~ '^[A-Z0-9]{3}$'),

  CONSTRAINT airlines_code_presence_check
    CHECK (iata IS NOT NULL OR icao IS NOT NULL),

  CONSTRAINT airlines_name_trimmed_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 160),

  CONSTRAINT airlines_slug_check
    CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

  CONSTRAINT airlines_logo_path_check
    CHECK (
      logo_path IS NULL
      OR (
        logo_path = btrim(logo_path)
        AND char_length(logo_path) BETWEEN 1 AND 512
        AND logo_path LIKE 'airlines/%'
        AND logo_path !~* '^[a-z][a-z0-9+.-]*://'
        AND logo_path !~ '(^|/)\.\.?(/|$)'
        AND logo_path !~ '[?#\\]'
      )
    ),

  CONSTRAINT airlines_alliance_trimmed_check
    CHECK (
      alliance IS NULL
      OR (
        alliance = btrim(alliance)
        AND char_length(alliance) BETWEEN 1 AND 80
      )
    ),

  CONSTRAINT airlines_business_model_check
    CHECK (
      business_model IN (
        'full_service',
        'low_cost',
        'regional',
        'charter',
        'cargo',
        'hybrid',
        'unknown'
      )
    ),

  CONSTRAINT airlines_status_check
    CHECK (status IN ('active', 'inactive', 'unknown'))
);

CREATE UNIQUE INDEX airlines_iata_key
ON public.airlines USING btree (iata)
WHERE iata IS NOT NULL;

CREATE UNIQUE INDEX airlines_icao_key
ON public.airlines USING btree (icao)
WHERE icao IS NOT NULL;

CREATE INDEX airlines_country_id_idx
ON public.airlines USING btree (country_id);

ALTER TABLE public.airlines ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airlines FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airlines TO service_role;
