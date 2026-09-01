-- Table: public.flight_route_options
-- Feature: Flight Route Discovery
-- Purpose: Pre-computed, versioned read projection of 0-stop direct and 1-stop connecting routes.
-- Responsibilities: Provide fast, indexable search and pSEO payload aggregation without real-time graph traversal.

CREATE TABLE public.flight_route_options (
  id                        UUID              NOT NULL DEFAULT gen_random_uuid(),
  publication_version_id    UUID              NOT NULL REFERENCES public.publication_versions (id) ON DELETE CASCADE,
  origin_city_id            UUID              NOT NULL REFERENCES public.cities (id),
  origin_city_slug          TEXT              NOT NULL,
  origin_country_code       TEXT              NOT NULL,
  destination_city_id       UUID              NOT NULL REFERENCES public.cities (id),
  destination_city_slug     TEXT              NOT NULL,
  destination_country_code  TEXT              NOT NULL,
  destination_region        TEXT              NULL,
  origin_airport_id         UUID              NOT NULL REFERENCES public.airports (id),
  origin_airport_iata       TEXT              NOT NULL,
  destination_airport_id    UUID              NOT NULL REFERENCES public.airports (id),
  destination_airport_iata  TEXT              NOT NULL,
  stops                     INTEGER           NOT NULL DEFAULT 0,
  layover_airport_ids       UUID[]            NOT NULL DEFAULT '{}',
  layover_airports          TEXT[]            NOT NULL DEFAULT '{}',
  operating_airlines        TEXT[]            NOT NULL DEFAULT '{}',
  flight_numbers            TEXT[]            NOT NULL DEFAULT '{}',
  flight_durations_minutes  INTEGER[]         NOT NULL DEFAULT '{}',
  total_duration_minutes    INTEGER           NOT NULL DEFAULT 0,
  total_distance_km         INTEGER           NOT NULL DEFAULT 0,
  days_of_week              INTEGER[]         NOT NULL DEFAULT '{1,2,3,4,5,6,7}',
  departure_time_buckets    TEXT[]            NOT NULL DEFAULT '{}',
  layover_minutes           INTEGER           NOT NULL DEFAULT 0,
  cabins                     TEXT[]            NOT NULL DEFAULT '{economy}',
  price_amount               NUMERIC(14,2)     NULL,
  price_currency             TEXT              NULL,
  route_type                TEXT              NOT NULL DEFAULT 'direct',
  confidence_score          NUMERIC(4,3)      NOT NULL DEFAULT 1.000,
  route_path                TEXT              NULL,
  created_at                TIMESTAMPTZ       NOT NULL DEFAULT now(),

  PRIMARY KEY (publication_version_id, id),

  CONSTRAINT flight_route_options_direction_check
    CHECK (origin_city_id <> destination_city_id),

  CONSTRAINT flight_route_options_stops_check
    CHECK (stops IN (0, 1)),

  CONSTRAINT flight_route_options_route_type_check
    CHECK (route_type IN ('direct', 'same_airline', 'alliance', 'self_transfer')),

  CONSTRAINT flight_route_options_departure_time_check
    CHECK (
      departure_time_buckets <@ ARRAY[
        'early_morning', 'morning', 'afternoon', 'evening'
      ]::TEXT[]
    ),

  CONSTRAINT flight_route_options_layover_check
    CHECK (layover_minutes >= 0),

  CONSTRAINT flight_route_options_cabins_check
    CHECK (
      cabins <@ ARRAY[
        'economy', 'premium_economy', 'business', 'first'
      ]::TEXT[]
    ),

  CONSTRAINT flight_route_options_price_check
    CHECK (
      (price_amount IS NULL AND price_currency IS NULL)
      OR (price_amount >= 0 AND price_currency ~ '^[A-Z]{3}$')
    )
);

CREATE INDEX flight_route_options_origin_idx ON public.flight_route_options
  (publication_version_id, origin_city_slug, confidence_score DESC, id);

CREATE INDEX flight_route_options_pair_idx ON public.flight_route_options
  (publication_version_id, origin_city_slug, destination_city_slug, stops, total_duration_minutes);

CREATE INDEX flight_route_options_airport_pair_idx ON public.flight_route_options
  (publication_version_id, origin_airport_iata, destination_airport_iata, stops);

ALTER TABLE public.flight_route_options ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.flight_route_options FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flight_route_options TO service_role;
