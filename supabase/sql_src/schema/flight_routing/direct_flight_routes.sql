-- Table: public.direct_flight_routes
-- Feature: Flight Routing
-- Purpose: Store normalized direct non-stop flight routes and schedules between airports.
-- Responsibilities: Act as canonical graph edges for direct routes and 1-stop connecting route calculations.

CREATE TABLE public.direct_flight_routes (
  id                      UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_airport_id       UUID              NOT NULL REFERENCES public.airports (id) ON DELETE CASCADE,
  destination_airport_id  UUID              NOT NULL REFERENCES public.airports (id) ON DELETE CASCADE,
  origin_iata             TEXT              NOT NULL,
  destination_iata        TEXT              NOT NULL,
  airline_iata            TEXT              NOT NULL,
  airline_name            TEXT              NOT NULL,
  airline_id              UUID              NULL REFERENCES public.airlines (id) ON DELETE SET NULL,
  flight_numbers          TEXT[]            NOT NULL DEFAULT '{}',
  flight_duration_minutes INTEGER           NOT NULL,
  distance_km             INTEGER           NOT NULL,
  days_of_week            INTEGER[]         NOT NULL DEFAULT '{1,2,3,4,5,6,7}',
  aircraft_types          TEXT[]            NOT NULL DEFAULT '{}',
  source_id               UUID              NOT NULL REFERENCES admin.data_sources (id),
  source_record_id        TEXT              NOT NULL,
  last_synced_at          TIMESTAMPTZ       NOT NULL DEFAULT now(),
  is_active               BOOLEAN           NOT NULL DEFAULT TRUE,
  created_at              TIMESTAMPTZ       NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ       NOT NULL DEFAULT now(),

  CONSTRAINT direct_flight_routes_source_record_key
    UNIQUE (source_id, source_record_id),

  CONSTRAINT direct_flight_routes_direction_check
    CHECK (origin_airport_id <> destination_airport_id),

  CONSTRAINT direct_flight_routes_origin_iata_check
    CHECK (origin_iata ~ '^[A-Z0-9]{3}$'),

  CONSTRAINT direct_flight_routes_destination_iata_check
    CHECK (destination_iata ~ '^[A-Z0-9]{3}$'),

  CONSTRAINT direct_flight_routes_airline_iata_check
    CHECK (airline_iata ~ '^[A-Z0-9]{2,3}$'),

  CONSTRAINT direct_flight_routes_duration_check
    CHECK (flight_duration_minutes > 0),

  CONSTRAINT direct_flight_routes_distance_check
    CHECK (distance_km > 0)
);

CREATE INDEX direct_flight_routes_origin_dest_idx ON public.direct_flight_routes
  (origin_iata, destination_iata) WHERE is_active = TRUE;

CREATE INDEX direct_flight_routes_dest_origin_idx ON public.direct_flight_routes
  (destination_iata, origin_iata) WHERE is_active = TRUE;

CREATE INDEX direct_flight_routes_origin_airport_idx ON public.direct_flight_routes
  (origin_airport_id);

CREATE INDEX direct_flight_routes_destination_airport_idx ON public.direct_flight_routes
  (destination_airport_id);

ALTER TABLE public.direct_flight_routes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.direct_flight_routes FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.direct_flight_routes TO service_role;
