-- Table: public.flight_content_observations
-- Feature: Flight Content
-- Purpose: Short-lived provider observations for pSEO display; never a live offer inventory.

CREATE TABLE public.flight_content_observations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_city_id UUID NOT NULL REFERENCES public.cities (id),
  destination_city_id UUID NOT NULL REFERENCES public.cities (id),
  origin_airport_id UUID NULL REFERENCES public.airports (id),
  destination_airport_id UUID NULL REFERENCES public.airports (id),
  canonical_airline_id UUID NULL REFERENCES public.airlines (id),
  provider_airline_iata TEXT NULL,
  observation_type TEXT NOT NULL,
  trip_type TEXT NOT NULL,
  direct BOOLEAN NULL,
  transfer_count INTEGER NULL,
  observed_amount NUMERIC(14,2) NULL,
  currency_code TEXT NULL,
  market_code TEXT NOT NULL,
  locale TEXT NOT NULL,
  departure_date DATE NULL,
  return_date DATE NULL,
  duration_minutes INTEGER NULL,
  source_id UUID NOT NULL REFERENCES admin.data_sources (id),
  source_record_id TEXT NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL,
  provider_expires_at TIMESTAMPTZ NULL,
  valid_until TIMESTAMPTZ NOT NULL,
  affiliate_path TEXT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  data_version UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT flight_content_observations_source_record_key UNIQUE (source_id, source_record_id),
  CONSTRAINT flight_content_observations_direction_check CHECK (origin_city_id <> destination_city_id),
  CONSTRAINT flight_content_observations_type_check CHECK (observation_type IN ('popular_direction', 'cached_fare', 'special_offer', 'price_calendar')),
  CONSTRAINT flight_content_observations_trip_check CHECK (trip_type IN ('one_way', 'return')),
  CONSTRAINT flight_content_observations_transfer_check CHECK (transfer_count IS NULL OR transfer_count >= 0),
  CONSTRAINT flight_content_observations_direct_check CHECK (direct IS NULL OR transfer_count IS NULL OR direct = (transfer_count = 0)),
  CONSTRAINT flight_content_observations_amount_check CHECK ((observed_amount IS NULL AND currency_code IS NULL) OR (observed_amount >= 0 AND currency_code ~ '^[A-Z]{3}$')),
  CONSTRAINT flight_content_observations_airline_check CHECK (provider_airline_iata IS NULL OR provider_airline_iata ~ '^[A-Z0-9]{2,3}$'),
  CONSTRAINT flight_content_observations_market_check CHECK (market_code ~ '^[a-z]{2}$'),
  CONSTRAINT flight_content_observations_locale_check CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),
  CONSTRAINT flight_content_observations_dates_check CHECK (return_date IS NULL OR departure_date IS NULL OR return_date >= departure_date),
  CONSTRAINT flight_content_observations_duration_check CHECK (duration_minutes IS NULL OR duration_minutes > 0),
  CONSTRAINT flight_content_observations_validity_check CHECK (valid_until > observed_at AND valid_until <= observed_at + interval '7 days' AND (provider_expires_at IS NULL OR valid_until <= provider_expires_at)),
  CONSTRAINT flight_content_observations_affiliate_check CHECK (affiliate_path IS NULL OR (affiliate_path LIKE '/%' AND affiliate_path NOT LIKE '//%')),
  CONSTRAINT flight_content_observations_status_check CHECK (status IN ('draft', 'published', 'expired'))
);

CREATE INDEX flight_content_observations_route_idx ON public.flight_content_observations
  (origin_city_id, destination_city_id, status, valid_until, market_code, currency_code);

ALTER TABLE public.flight_content_observations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.flight_content_observations FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flight_content_observations TO service_role;
