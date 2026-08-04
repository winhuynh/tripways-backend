-- Table: public.metro_area_airports
-- Feature: Place Discovery
-- Purpose: Associate airports with a multi-airport market.

CREATE TABLE public.metro_area_airports (
  metro_area_id  UUID         NOT NULL REFERENCES public.metro_areas (id) ON DELETE CASCADE,
  airport_id     UUID         NOT NULL REFERENCES public.airports (id),
  relevance      NUMERIC(6,5) NOT NULL DEFAULT 1,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

  PRIMARY KEY (metro_area_id, airport_id),
  CONSTRAINT metro_area_airports_relevance_check CHECK (relevance BETWEEN 0 AND 1)
);

CREATE INDEX metro_area_airports_airport_idx ON public.metro_area_airports USING btree (airport_id);
ALTER TABLE public.metro_area_airports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.metro_area_airports FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.metro_area_airports TO service_role;

