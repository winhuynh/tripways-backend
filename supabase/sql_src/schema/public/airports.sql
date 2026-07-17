-- Table: public.airports
-- Feature: Flight Routing
-- Purpose: Represent the airport nodes used by direct and one-stop route search.
-- Responsibilities: Enforce codes, location, operational state, and source lineage.

CREATE TABLE public.airports (
  id                UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  iata              TEXT              NULL,
  icao              TEXT              NULL,
  name              TEXT              NOT NULL,
  slug              TEXT              NOT NULL UNIQUE,
  city_id           UUID              NULL REFERENCES public.cities (id),
  country_id        UUID              NOT NULL REFERENCES public.countries (id),
  latitude          DOUBLE PRECISION  NOT NULL,
  longitude         DOUBLE PRECISION  NOT NULL,
  timezone          TEXT              NULL,
  airport_type      TEXT              NOT NULL,
  status            TEXT              NOT NULL DEFAULT 'unknown',
  source_id         UUID              NOT NULL REFERENCES admin.data_sources (id),
  source_record_id  TEXT              NOT NULL,
  last_verified_at  TIMESTAMPTZ       NULL,
  created_at        TIMESTAMPTZ       NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ       NOT NULL DEFAULT now(),

  CONSTRAINT airports_source_record_key
    UNIQUE (source_id, source_record_id),

  CONSTRAINT airports_iata_check
    CHECK (iata IS NULL OR iata ~ '^[A-Z]{3}$'),

  CONSTRAINT airports_icao_check
    CHECK (icao IS NULL OR icao ~ '^[A-Z0-9]{4}$'),

  CONSTRAINT airports_code_presence_check
    CHECK (iata IS NOT NULL OR icao IS NOT NULL),

  CONSTRAINT airports_name_trimmed_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 160),

  CONSTRAINT airports_slug_check
    CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

  CONSTRAINT airports_latitude_check
    CHECK (latitude BETWEEN -90 AND 90),

  CONSTRAINT airports_longitude_check
    CHECK (longitude BETWEEN -180 AND 180),

  CONSTRAINT airports_type_check
    CHECK (
      airport_type IN (
        'large_airport',
        'medium_airport',
        'small_airport',
        'heliport',
        'seaplane_base',
        'balloonport',
        'closed'
      )
    ),

  CONSTRAINT airports_status_check
    CHECK (status IN ('active', 'inactive', 'unknown'))
);

CREATE UNIQUE INDEX airports_iata_key
ON public.airports USING btree (iata)
WHERE iata IS NOT NULL;

CREATE UNIQUE INDEX airports_icao_key
ON public.airports USING btree (icao)
WHERE icao IS NOT NULL;

CREATE INDEX airports_city_id_idx
ON public.airports USING btree (city_id);

CREATE INDEX airports_country_id_idx
ON public.airports USING btree (country_id);

ALTER TABLE public.airports ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airports FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airports TO service_role;
