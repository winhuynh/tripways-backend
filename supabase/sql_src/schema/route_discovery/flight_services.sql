-- Table: public.flight_services
-- Feature: Route Discovery
-- Purpose: Store recurring flight schedule patterns used to build route options.
-- Responsibilities: Preserve route attribution, operating days, local times, and source lineage.

CREATE TABLE public.flight_services (
  id                    UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_route_id       UUID           NOT NULL REFERENCES public.flight_routes (id),
  operating_airline_id  UUID           NOT NULL REFERENCES public.airlines (id),
  marketing_airline_id  UUID           NULL REFERENCES public.airlines (id),
  flight_number         TEXT           NOT NULL,
  valid_from            DATE           NOT NULL,
  valid_to              DATE           NOT NULL,
  days_of_week          SMALLINT[]     NOT NULL,
  departure_local_time  TIME           NOT NULL,
  arrival_local_time    TIME           NOT NULL,
  arrival_day_offset    SMALLINT       NOT NULL DEFAULT 0,
  duration_minutes      INTEGER        NOT NULL,
  aircraft_type         TEXT           NULL,
  confidence_score      NUMERIC(4, 3)  NOT NULL,
  source_id             UUID           NOT NULL REFERENCES admin.data_sources (id),
  source_record_id      TEXT           NOT NULL,
  last_verified_at      TIMESTAMPTZ    NOT NULL,
  created_at            TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT flight_services_source_record_key
    UNIQUE (source_id, source_record_id),

  CONSTRAINT flight_services_flight_number_check
    CHECK (
      flight_number = btrim(flight_number)
      AND flight_number ~ '^[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?$'
    ),

  CONSTRAINT flight_services_validity_check
    CHECK (valid_from <= valid_to),

  CONSTRAINT flight_services_days_check
    CHECK (
      cardinality(days_of_week) BETWEEN 1 AND 7
      AND days_of_week <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::SMALLINT[]
    ),

  CONSTRAINT flight_services_arrival_offset_check
    CHECK (arrival_day_offset BETWEEN 0 AND 2),

  CONSTRAINT flight_services_duration_check
    CHECK (duration_minutes BETWEEN 1 AND 1440),

  CONSTRAINT flight_services_aircraft_type_check
    CHECK (
      aircraft_type IS NULL
      OR (
        aircraft_type = btrim(aircraft_type)
        AND char_length(aircraft_type) BETWEEN 1 AND 32
      )
    ),

  CONSTRAINT flight_services_confidence_check
    CHECK (confidence_score BETWEEN 0 AND 1)
);

CREATE INDEX flight_services_route_validity_idx
ON public.flight_services USING btree (flight_route_id, valid_from, valid_to);

CREATE INDEX flight_services_operating_airline_idx
ON public.flight_services USING btree (operating_airline_id);

CREATE INDEX flight_services_marketing_airline_idx
ON public.flight_services USING btree (marketing_airline_id)
WHERE marketing_airline_id IS NOT NULL;

ALTER TABLE public.flight_services ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.flight_services FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flight_services TO service_role;
