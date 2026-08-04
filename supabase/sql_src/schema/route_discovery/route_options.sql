-- Table: public.route_options
-- Feature: Route Discovery
-- Purpose: Store precomputed direct through three-stop schedule options for bounded search.
-- Responsibilities: Preserve filterable route shape, duration, schedule validity, and data version.

CREATE TABLE public.route_options (
  id                      UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_airport_id       UUID           NOT NULL REFERENCES public.airports (id),
  destination_airport_id  UUID           NOT NULL REFERENCES public.airports (id),
  stop_count              SMALLINT       NOT NULL,
  service_ids             UUID[]         NOT NULL,
  flight_route_ids        UUID[]         NOT NULL,
  origin_airport_ids      UUID[]         NOT NULL,
  destination_airport_ids UUID[]         NOT NULL,
  connection_airport_ids  UUID[]         NOT NULL DEFAULT '{}'::UUID[],
  operating_airline_ids   UUID[]         NOT NULL,
  marketing_airline_ids   UUID[]         NOT NULL,
  departure_local_times   TIME[]         NOT NULL,
  arrival_local_times     TIME[]         NOT NULL,
  leg_duration_minutes    INTEGER[]      NOT NULL,
  layover_minutes_by_connection INTEGER[] NOT NULL DEFAULT '{}'::INTEGER[],
  total_flight_minutes    INTEGER        NOT NULL,
  layover_minutes         INTEGER        NOT NULL DEFAULT 0,
  total_duration_minutes  INTEGER        NOT NULL,
  departure_local_time    TIME           NOT NULL,
  arrival_local_time      TIME           NOT NULL,
  arrival_day_offset      SMALLINT       NOT NULL,
  valid_from              DATE           NOT NULL,
  valid_to                DATE           NOT NULL,
  days_of_week            SMALLINT[]     NOT NULL,
  confidence_score        NUMERIC(4, 3)  NOT NULL,
  data_version            UUID           NOT NULL,
  generated_at            TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT route_options_services_key
    UNIQUE (service_ids),

  CONSTRAINT route_options_direction_check
    CHECK (origin_airport_id <> destination_airport_id),

  CONSTRAINT route_options_stop_count_check
    CHECK (stop_count BETWEEN 0 AND 3),

  CONSTRAINT route_options_shape_check
    CHECK (
      cardinality(service_ids) = stop_count + 1
      AND cardinality(flight_route_ids) = stop_count + 1
      AND cardinality(origin_airport_ids) = stop_count + 1
      AND cardinality(destination_airport_ids) = stop_count + 1
      AND cardinality(connection_airport_ids) = stop_count
      AND cardinality(operating_airline_ids) = stop_count + 1
      AND cardinality(marketing_airline_ids) = stop_count + 1
      AND cardinality(departure_local_times) = stop_count + 1
      AND cardinality(arrival_local_times) = stop_count + 1
      AND cardinality(leg_duration_minutes) = stop_count + 1
      AND cardinality(layover_minutes_by_connection) = stop_count
    ),

  CONSTRAINT route_options_duration_check
    CHECK (
      total_flight_minutes > 0
      AND layover_minutes >= 0
      AND total_duration_minutes = total_flight_minutes + layover_minutes
    ),

  CONSTRAINT route_options_arrival_offset_check
    CHECK (arrival_day_offset BETWEEN 0 AND 7),

  CONSTRAINT route_options_validity_check
    CHECK (valid_from <= valid_to),

  CONSTRAINT route_options_days_check
    CHECK (
      cardinality(days_of_week) BETWEEN 1 AND 7
      AND days_of_week <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::SMALLINT[]
    ),

  CONSTRAINT route_options_confidence_check
    CHECK (confidence_score BETWEEN 0 AND 1)
);

CREATE INDEX route_options_search_idx
ON public.route_options USING btree (
  origin_airport_id,
  destination_airport_id,
  stop_count,
  total_duration_minutes
);

CREATE INDEX route_options_operating_airlines_idx
ON public.route_options USING gin (operating_airline_ids);

CREATE INDEX route_options_connections_idx
ON public.route_options USING gin (connection_airport_ids);

ALTER TABLE public.route_options ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.route_options FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_options TO service_role;
