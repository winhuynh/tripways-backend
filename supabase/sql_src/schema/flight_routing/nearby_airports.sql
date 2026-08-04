-- Table: public.nearby_airports
-- Feature: Place Discovery
-- Purpose: Store directional nearby-airport alternatives with deterministic relevance.

CREATE TABLE public.nearby_airports (
  airport_id         UUID         NOT NULL REFERENCES public.airports (id),
  nearby_airport_id  UUID         NOT NULL REFERENCES public.airports (id),
  distance_km        NUMERIC(8,2) NOT NULL,
  relevance          NUMERIC(6,5) NOT NULL,
  source_id          UUID         NOT NULL REFERENCES admin.data_sources (id),
  last_verified_at   TIMESTAMPTZ  NOT NULL,
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),

  PRIMARY KEY (airport_id, nearby_airport_id),
  CONSTRAINT nearby_airports_direction_check CHECK (airport_id <> nearby_airport_id),
  CONSTRAINT nearby_airports_distance_check CHECK (distance_km > 0),
  CONSTRAINT nearby_airports_relevance_check CHECK (relevance BETWEEN 0 AND 1)
);

ALTER TABLE public.nearby_airports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.nearby_airports FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.nearby_airports TO service_role;

