-- Table: public.route_price_estimates
-- Feature: Route Price Estimates
-- Purpose: Store provider-neutral derived price ranges without live offer or availability claims.

CREATE TABLE public.route_price_estimates (
  id                      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_city_id          UUID          NOT NULL REFERENCES public.cities (id),
  destination_city_id     UUID          NOT NULL REFERENCES public.cities (id),
  origin_airport_id       UUID          NULL REFERENCES public.airports (id),
  destination_airport_id  UUID          NULL REFERENCES public.airports (id),
  airline_id              UUID          NULL REFERENCES public.airlines (id),
  trip_type               TEXT          NOT NULL,
  cabin                   TEXT          NOT NULL,
  stop_bucket             TEXT          NOT NULL,
  baggage_included        BOOLEAN       NULL,
  price_min               NUMERIC(14,2) NOT NULL,
  price_max               NUMERIC(14,2) NOT NULL,
  currency_code           TEXT          NOT NULL,
  estimate_method         TEXT          NOT NULL,
  sample_window_start     DATE          NOT NULL,
  sample_window_end       DATE          NOT NULL,
  sample_count            INTEGER       NULL,
  source_id               UUID          NOT NULL REFERENCES admin.data_sources (id),
  source_record_id        TEXT          NOT NULL,
  confidence_score        NUMERIC(4,3)  NOT NULL,
  last_verified_at        TIMESTAMPTZ   NOT NULL,
  valid_until             TIMESTAMPTZ   NOT NULL,
  status                  TEXT          NOT NULL DEFAULT 'draft',
  data_version            UUID          NOT NULL,
  created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT route_price_estimates_source_record_key UNIQUE (source_id, source_record_id),
  CONSTRAINT route_price_estimates_direction_check CHECK (origin_city_id <> destination_city_id),
  CONSTRAINT route_price_estimates_trip_type_check CHECK (trip_type IN ('one_way', 'return')),
  CONSTRAINT route_price_estimates_cabin_check CHECK (cabin IN ('economy', 'premium_economy', 'business', 'first', 'any')),
  CONSTRAINT route_price_estimates_stops_check CHECK (stop_bucket IN ('direct', 'one_stop', 'two_stops', 'three_stops', 'any')),
  CONSTRAINT route_price_estimates_price_check CHECK (price_min >= 0 AND price_max >= price_min),
  CONSTRAINT route_price_estimates_currency_check CHECK (currency_code ~ '^[A-Z]{3}$'),
  CONSTRAINT route_price_estimates_window_check CHECK (sample_window_start <= sample_window_end),
  CONSTRAINT route_price_estimates_sample_check CHECK (sample_count IS NULL OR sample_count > 0),
  CONSTRAINT route_price_estimates_confidence_check CHECK (confidence_score BETWEEN 0 AND 1),
  CONSTRAINT route_price_estimates_validity_check CHECK (valid_until > last_verified_at),
  CONSTRAINT route_price_estimates_status_check CHECK (status IN ('draft', 'review', 'published', 'expired'))
);

CREATE INDEX route_price_estimates_market_idx ON public.route_price_estimates USING btree (origin_city_id, destination_city_id, status, valid_until, cabin, stop_bucket);
ALTER TABLE public.route_price_estimates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_price_estimates FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_price_estimates TO service_role;

