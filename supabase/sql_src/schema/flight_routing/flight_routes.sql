-- Table: public.flight_routes
-- Feature: Flight Routing
-- Purpose: Store short-lived directional route evidence, not schedules.

CREATE TABLE public.flight_routes (
  id                      UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_airport_id       UUID           NOT NULL REFERENCES public.airports (id),
  destination_airport_id  UUID           NOT NULL REFERENCES public.airports (id),
  canonical_airline_id    UUID           NULL REFERENCES public.airlines (id),
  provider_airline_iata   TEXT           NULL,
  evidence_type           TEXT           NOT NULL,
  status                  TEXT           NOT NULL DEFAULT 'unknown',
  confidence_score        NUMERIC(4, 3)  NOT NULL,
  source_id               UUID           NOT NULL REFERENCES admin.data_sources (id),
  source_record_id        TEXT           NOT NULL,
  observed_at             TIMESTAMPTZ    NOT NULL,
  valid_until             TIMESTAMPTZ    NULL,
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

  CONSTRAINT flight_routes_airline_iata_check
    CHECK (provider_airline_iata IS NULL OR provider_airline_iata ~ '^[A-Z0-9]{2,3}$'),

  CONSTRAINT flight_routes_evidence_type_check
    CHECK (evidence_type IN ('provider_route', 'content_observation', 'manual')),

  CONSTRAINT flight_routes_validity_check
    CHECK (valid_until IS NULL OR valid_until > observed_at),

  CONSTRAINT flight_routes_confidence_check
    CHECK (confidence_score BETWEEN 0 AND 1)
);

CREATE INDEX flight_routes_direction_idx
ON public.flight_routes USING btree (origin_airport_id, destination_airport_id);

CREATE INDEX flight_routes_origin_status_destination_idx
ON public.flight_routes USING btree (origin_airport_id, status, destination_airport_id);

CREATE INDEX flight_routes_destination_status_idx
ON public.flight_routes USING btree (destination_airport_id, status);

CREATE INDEX flight_routes_airline_status_idx
ON public.flight_routes USING btree (canonical_airline_id, status);

ALTER TABLE public.flight_routes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.flight_routes FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flight_routes TO service_role;
