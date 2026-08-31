-- Table: public.flight_route_prices
-- Feature: Flight Route Prices
-- Purpose: Store short-lived provider prices for pSEO display; never a live offer inventory.

CREATE TABLE public.flight_route_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_reference TEXT NOT NULL DEFAULT ('obs_' || replace(gen_random_uuid()::TEXT, '-', '')),
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
  provider_code TEXT NOT NULL,
  source_record_id TEXT NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL,
  valid_until TIMESTAMPTZ NOT NULL,
  affiliate_path TEXT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT flight_route_prices_source_record_key UNIQUE (source_id, source_record_id),
  CONSTRAINT flight_route_prices_public_reference_key UNIQUE (public_reference),
  CONSTRAINT flight_route_prices_public_reference_check CHECK (public_reference ~ '^obs_[0-9a-f]{32}$'),
  CONSTRAINT flight_route_prices_direction_check CHECK (origin_city_id <> destination_city_id),
  CONSTRAINT flight_route_prices_type_check
    CHECK (observation_type IN ('popular_direction', 'cached_fare', 'special_offer', 'price_calendar')),
  CONSTRAINT flight_route_prices_trip_check CHECK (trip_type IN ('one_way', 'return')),
  CONSTRAINT flight_route_prices_transfer_check CHECK (transfer_count IS NULL OR transfer_count >= 0),
  CONSTRAINT flight_route_prices_direct_check CHECK (direct IS NULL OR transfer_count IS NULL OR direct = (transfer_count = 0)),
  CONSTRAINT flight_route_prices_amount_check
    CHECK (
      (observed_amount IS NULL AND currency_code IS NULL)
      OR (observed_amount >= 0 AND currency_code ~ '^[A-Z]{3}$')
    ),
  CONSTRAINT flight_route_prices_airline_check CHECK (provider_airline_iata IS NULL OR provider_airline_iata ~ '^[A-Z0-9]{2,3}$'),
  CONSTRAINT flight_route_prices_market_check CHECK (market_code ~ '^[a-z]{2}$'),
  CONSTRAINT flight_route_prices_provider_check CHECK (provider_code ~ '^[a-z0-9]+(?:[_-][a-z0-9]+)*$'),
  CONSTRAINT flight_route_prices_locale_check CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),
  CONSTRAINT flight_route_prices_dates_check CHECK (return_date IS NULL OR departure_date IS NULL OR return_date >= departure_date),
  CONSTRAINT flight_route_prices_duration_check CHECK (duration_minutes IS NULL OR duration_minutes > 0),
  CONSTRAINT flight_route_prices_validity_check
    CHECK (
      valid_until > observed_at
      AND valid_until <= observed_at + interval '7 days'
    ),
  CONSTRAINT flight_route_prices_affiliate_check CHECK (affiliate_path IS NULL OR (affiliate_path LIKE '/%' AND affiliate_path NOT LIKE '//%')),
  CONSTRAINT flight_route_prices_status_check CHECK (status IN ('draft', 'published', 'expired'))
);

CREATE INDEX flight_route_prices_route_idx ON public.flight_route_prices
  (origin_city_id, destination_city_id, status, valid_until, market_code, currency_code);

ALTER TABLE public.flight_route_prices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.flight_route_prices FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flight_route_prices TO service_role;
