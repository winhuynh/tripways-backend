-- Table: public.pseo_direct_routes
-- Feature: Interactive pSEO
-- Purpose: Provide a rebuildable, filterable projection of direct routes from a city.
-- Responsibilities: Preserve scalar airport, airline, country, schedule, confidence, and freshness dimensions.

CREATE TABLE public.pseo_direct_routes (
  id                         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_city_id             UUID           NOT NULL REFERENCES public.cities (id),
  origin_airport_id          UUID           NOT NULL REFERENCES public.airports (id),
  origin_country_id          UUID           NOT NULL REFERENCES public.countries (id),
  destination_city_id        UUID           NOT NULL REFERENCES public.cities (id),
  destination_airport_id     UUID           NOT NULL REFERENCES public.airports (id),
  destination_country_id     UUID           NOT NULL REFERENCES public.countries (id),
  operating_airline_id       UUID           NOT NULL REFERENCES public.airlines (id),
  marketing_airline_id       UUID           NULL REFERENCES public.airlines (id),
  flight_route_id            UUID           NOT NULL REFERENCES public.flight_routes (id),
  service_count              INTEGER        NOT NULL,
  frequency_per_week         NUMERIC(6, 2)  NULL,
  shortest_duration_minutes  INTEGER        NOT NULL,
  longest_duration_minutes   INTEGER        NOT NULL,
  earliest_departure_time    TIME           NOT NULL,
  latest_departure_time      TIME           NOT NULL,
  seasonality                TEXT           NOT NULL,
  seasonal_start             DATE           NULL,
  seasonal_end               DATE           NULL,
  confidence_score           NUMERIC(4, 3)  NOT NULL,
  source_freshness_at        TIMESTAMPTZ    NOT NULL,
  data_version               UUID           NOT NULL,
  generated_at               TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT pseo_direct_routes_version_route_key
    UNIQUE (data_version, flight_route_id),

  CONSTRAINT pseo_direct_routes_direction_check
    CHECK (origin_city_id <> destination_city_id),

  CONSTRAINT pseo_direct_routes_service_count_check
    CHECK (service_count > 0),

  CONSTRAINT pseo_direct_routes_duration_check
    CHECK (
      shortest_duration_minutes > 0
      AND longest_duration_minutes >= shortest_duration_minutes
    ),

  CONSTRAINT pseo_direct_routes_frequency_check
    CHECK (frequency_per_week IS NULL OR frequency_per_week >= 0),

  CONSTRAINT pseo_direct_routes_seasonality_check
    CHECK (seasonality IN ('year_round', 'seasonal', 'unknown')),

  CONSTRAINT pseo_direct_routes_seasonal_dates_check
    CHECK ((seasonal_start IS NULL) = (seasonal_end IS NULL)),

  CONSTRAINT pseo_direct_routes_confidence_check
    CHECK (confidence_score BETWEEN 0 AND 1)
);

CREATE INDEX pseo_direct_routes_origin_city_idx
ON public.pseo_direct_routes USING btree (
  origin_city_id,
  data_version,
  destination_city_id
);

CREATE INDEX pseo_direct_routes_destination_city_idx
ON public.pseo_direct_routes USING btree (
  destination_city_id,
  data_version,
  origin_city_id
);

CREATE INDEX pseo_direct_routes_origin_airport_idx
ON public.pseo_direct_routes USING btree (
  origin_airport_id,
  data_version,
  destination_airport_id
);

CREATE INDEX pseo_direct_routes_destination_airport_idx
ON public.pseo_direct_routes USING btree (
  destination_airport_id,
  data_version,
  origin_airport_id
);

CREATE INDEX pseo_direct_routes_origin_airline_idx
ON public.pseo_direct_routes USING btree (
  origin_airport_id,
  data_version,
  operating_airline_id
);

CREATE INDEX pseo_direct_routes_destination_airline_idx
ON public.pseo_direct_routes USING btree (
  destination_airport_id,
  data_version,
  operating_airline_id,
  origin_airport_id
);

CREATE INDEX pseo_direct_routes_origin_country_idx
ON public.pseo_direct_routes USING btree (
  origin_airport_id,
  data_version,
  destination_country_id,
  destination_airport_id
);

CREATE INDEX pseo_direct_routes_destination_country_idx
ON public.pseo_direct_routes USING btree (
  destination_airport_id,
  data_version,
  origin_country_id,
  origin_airport_id
);

CREATE INDEX pseo_direct_routes_origin_duration_idx
ON public.pseo_direct_routes USING btree (
  origin_airport_id,
  data_version,
  shortest_duration_minutes,
  destination_airport_id
);

ALTER TABLE public.pseo_direct_routes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.pseo_direct_routes FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.pseo_direct_routes TO service_role;
