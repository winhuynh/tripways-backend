-- Table: public.flight_route_options
-- Feature: Flight Route Discovery
-- Purpose: Disposable, versioned read projection built from route evidence and fresh observations.

CREATE TABLE public.flight_route_options (
  id UUID NOT NULL,
  publication_version_id UUID NOT NULL REFERENCES public.publication_versions (id) ON DELETE CASCADE,
  origin_city_id UUID NOT NULL REFERENCES public.cities (id),
  origin_city_slug TEXT NOT NULL,
  origin_country_code TEXT NOT NULL,
  destination_city_id UUID NOT NULL REFERENCES public.cities (id),
  destination_city_slug TEXT NOT NULL,
  destination_country_code TEXT NOT NULL,
  origin_airport_id UUID NOT NULL REFERENCES public.airports (id),
  origin_airport_iata TEXT NOT NULL,
  destination_airport_id UUID NOT NULL REFERENCES public.airports (id),
  destination_airport_iata TEXT NOT NULL,
  canonical_airline_id UUID NULL REFERENCES public.airlines (id),
  provider_airline_iata TEXT NULL,
  evidence_type TEXT NOT NULL,
  confidence_score NUMERIC(4,3) NOT NULL,
  observed_amount NUMERIC(14,2) NULL,
  currency_code TEXT NULL,
  observation_valid_until TIMESTAMPTZ NULL,
  route_path TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (publication_version_id, id),
  CONSTRAINT flight_route_options_direction_check CHECK (origin_city_id <> destination_city_id),
  CONSTRAINT flight_route_options_amount_check CHECK ((observed_amount IS NULL AND currency_code IS NULL) OR (observed_amount >= 0 AND currency_code ~ '^[A-Z]{3}$'))
);

CREATE INDEX flight_route_options_origin_idx ON public.flight_route_options
  (publication_version_id, origin_city_slug, confidence_score DESC, id);
CREATE INDEX flight_route_options_pair_idx ON public.flight_route_options
  (publication_version_id, origin_city_slug, destination_city_slug, confidence_score DESC, id);

ALTER TABLE public.flight_route_options ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.flight_route_options FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flight_route_options TO service_role;
