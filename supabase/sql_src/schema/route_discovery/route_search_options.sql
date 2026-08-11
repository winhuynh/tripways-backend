-- Table: public.route_search_options
-- Feature: Shared Route Search
-- Purpose: Materialize one searchable provider-neutral projection for every page consumer.

CREATE TABLE public.route_search_options (
  id                       UUID           NOT NULL,
  publication_version_id   UUID           NOT NULL REFERENCES public.publication_versions (id) ON DELETE CASCADE,
  origin_city_id           UUID           NOT NULL REFERENCES public.cities (id),
  origin_city_slug         TEXT           NOT NULL,
  origin_country_code      TEXT           NOT NULL,
  origin_region_code       TEXT           NULL,
  destination_city_id      UUID           NOT NULL REFERENCES public.cities (id),
  destination_city_slug    TEXT           NOT NULL,
  destination_country_code TEXT           NOT NULL,
  destination_region_code  TEXT           NULL,
  is_international         BOOLEAN        NOT NULL,
  origin_airport_id        UUID           NOT NULL REFERENCES public.airports (id),
  origin_airport_iata      TEXT           NOT NULL,
  destination_airport_id   UUID           NOT NULL REFERENCES public.airports (id),
  destination_airport_iata TEXT           NOT NULL,
  stop_count               SMALLINT       NOT NULL,
  connection_airport_ids   UUID[]         NOT NULL,
  connection_airport_iatas TEXT[]         NOT NULL,
  operating_airline_ids    UUID[]         NOT NULL,
  operating_airline_iatas  TEXT[]         NOT NULL,
  departure_local_time     TIME           NOT NULL,
  departure_time_bucket    TEXT           NOT NULL,
  arrival_local_time       TIME           NOT NULL,
  arrival_day_offset       SMALLINT       NOT NULL,
  days_of_week             SMALLINT[]     NOT NULL,
  valid_from               DATE           NOT NULL,
  valid_to                 DATE           NOT NULL,
  total_flight_minutes     INTEGER        NOT NULL,
  layover_minutes          INTEGER        NOT NULL,
  maximum_layover_minutes  INTEGER        NOT NULL,
  total_duration_minutes   INTEGER        NOT NULL,
  confidence_score         NUMERIC(4,3)   NOT NULL,
  route_path               TEXT           NULL,
  price_state              TEXT           NOT NULL,
  price_trip_type          TEXT           NULL,
  price_min                NUMERIC(14,2)  NULL,
  price_max                NUMERIC(14,2)  NULL,
  currency_code            TEXT           NULL,
  price_valid_until        TIMESTAMPTZ    NULL,
  created_at               TIMESTAMPTZ    NOT NULL DEFAULT now(),

  PRIMARY KEY (publication_version_id, id),

  CONSTRAINT route_search_options_stops_check
    CHECK (stop_count BETWEEN 0 AND 3),

  CONSTRAINT route_search_options_shape_check
    CHECK (
      cardinality(connection_airport_ids) = stop_count
      AND cardinality(connection_airport_iatas) = stop_count
      AND cardinality(operating_airline_ids) = stop_count + 1
      AND cardinality(operating_airline_iatas) = stop_count + 1
    ),

  CONSTRAINT route_search_options_country_code_check
    CHECK (
      origin_country_code ~ '^[A-Z]{2}$'
      AND destination_country_code ~ '^[A-Z]{2}$'
    ),

  CONSTRAINT route_search_options_departure_bucket_check
    CHECK (departure_time_bucket IN ('early_morning', 'morning', 'afternoon', 'evening')),

  CONSTRAINT route_search_options_price_check
    CHECK (
      (price_state = 'available' AND price_trip_type = 'one_way' AND price_min IS NOT NULL AND price_max >= price_min AND currency_code ~ '^[A-Z]{3}$' AND price_valid_until IS NOT NULL)
      OR
      (price_state IN ('missing', 'expired', 'unlicensed') AND price_trip_type IS NULL AND price_min IS NULL AND price_max IS NULL AND currency_code IS NULL AND price_valid_until IS NULL)
    )
);

CREATE INDEX route_search_options_origin_city_rank_idx
ON public.route_search_options USING btree (
  publication_version_id,
  origin_city_slug,
  stop_count,
  total_duration_minutes,
  confidence_score DESC,
  id
);

CREATE INDEX route_search_options_origin_airport_rank_idx
ON public.route_search_options USING btree (
  publication_version_id,
  origin_airport_iata,
  stop_count,
  total_duration_minutes,
  confidence_score DESC,
  id
);

CREATE INDEX route_search_options_city_pair_rank_idx
ON public.route_search_options USING btree (
  publication_version_id,
  origin_city_slug,
  destination_city_slug,
  stop_count,
  total_duration_minutes,
  confidence_score DESC,
  id
);

CREATE INDEX route_search_options_global_rank_idx
ON public.route_search_options USING btree (
  publication_version_id,
  stop_count,
  total_duration_minutes,
  confidence_score DESC,
  id
);

CREATE INDEX route_search_options_airlines_idx
ON public.route_search_options USING gin (operating_airline_iatas);

CREATE INDEX route_search_options_connections_idx
ON public.route_search_options USING gin (connection_airport_iatas);

CREATE INDEX route_search_options_destination_geography_idx
ON public.route_search_options USING btree (
  publication_version_id,
  destination_country_code,
  destination_region_code,
  is_international
);

CREATE INDEX route_search_options_origin_geography_idx
ON public.route_search_options USING btree (
  publication_version_id,
  origin_country_code,
  origin_region_code,
  is_international
);

ALTER TABLE public.route_search_options ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_search_options FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_search_options TO service_role;
