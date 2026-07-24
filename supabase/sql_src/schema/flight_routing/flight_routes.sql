-- Table: public.flight_routes
-- Feature: Flight Routing
-- Purpose: Store directional scheduled-flight relationships used by route search.
-- Responsibilities: Preserve airline attribution, schedule hints, trust state, and source lineage.

CREATE TABLE public.flight_routes (
  id                      UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_airport_id       UUID           NOT NULL REFERENCES public.airports (id),
  destination_airport_id  UUID           NOT NULL REFERENCES public.airports (id),
  operating_airline_id    UUID           NULL REFERENCES public.airlines (id),
  marketing_airline_id    UUID           NULL REFERENCES public.airlines (id),
  is_codeshare            BOOLEAN        NOT NULL DEFAULT FALSE,
  status                  TEXT           NOT NULL DEFAULT 'unknown',
  frequency_per_week      NUMERIC(6, 2)  NULL,
  days_of_week            SMALLINT[]     NULL,
  seasonality             TEXT           NOT NULL DEFAULT 'unknown',
  seasonal_start          DATE           NULL,
  seasonal_end            DATE           NULL,
  confidence_score        NUMERIC(4, 3)  NOT NULL,
  source_id               UUID           NOT NULL REFERENCES admin.data_sources (id),
  source_record_id        TEXT           NOT NULL,
  last_verified_at        TIMESTAMPTZ    NOT NULL,
  created_at              TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT flight_routes_source_record_key
    UNIQUE (source_id, source_record_id),

  CONSTRAINT flight_routes_direction_check
    CHECK (origin_airport_id <> destination_airport_id),

  CONSTRAINT flight_routes_status_check
    CHECK (
      status IN (
        'verified_active',
        'likely_active',
        'seasonal',
        'unknown',
        'historical',
        'inactive',
        'low_confidence'
      )
    ),

  CONSTRAINT flight_routes_frequency_check
    CHECK (frequency_per_week IS NULL OR frequency_per_week >= 0),

  CONSTRAINT flight_routes_days_check
    CHECK (
      days_of_week IS NULL
      OR (
        cardinality(days_of_week) BETWEEN 1 AND 7
        AND days_of_week <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::SMALLINT[]
      )
    ),

  CONSTRAINT flight_routes_seasonality_check
    CHECK (seasonality IN ('year_round', 'seasonal', 'unknown')),

  CONSTRAINT flight_routes_seasonal_dates_check
    CHECK ((seasonal_start IS NULL) = (seasonal_end IS NULL)),

  CONSTRAINT flight_routes_seasonal_order_check
    CHECK (seasonal_start IS NULL OR seasonal_start <= seasonal_end),

  CONSTRAINT flight_routes_confidence_check
    CHECK (confidence_score BETWEEN 0 AND 1)
);

CREATE INDEX flight_routes_direction_idx
ON public.flight_routes USING btree (origin_airport_id, destination_airport_id);

CREATE INDEX flight_routes_origin_status_destination_idx
ON public.flight_routes USING btree (origin_airport_id, status, destination_airport_id);

CREATE INDEX flight_routes_destination_status_idx
ON public.flight_routes USING btree (destination_airport_id, status);

CREATE INDEX flight_routes_operating_airline_status_idx
ON public.flight_routes USING btree (operating_airline_id, status);

ALTER TABLE public.flight_routes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.flight_routes FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flight_routes TO service_role;
