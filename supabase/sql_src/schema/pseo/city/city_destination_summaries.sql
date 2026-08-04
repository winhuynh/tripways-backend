-- Table: public.city_destination_summaries
-- Feature: Interactive pSEO
-- Purpose: Provide stable default cards and ranking for city-to-city direct destinations.
-- Responsibilities: Aggregate direct route facts without replacing filterable route-level data.

CREATE TABLE public.city_destination_summaries (
  id                         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_city_id             UUID            NOT NULL REFERENCES public.cities (id),
  destination_city_id        UUID            NOT NULL REFERENCES public.cities (id),
  destination_country_id     UUID            NOT NULL REFERENCES public.countries (id),
  origin_airport_count       INTEGER         NOT NULL,
  destination_airport_count  INTEGER         NOT NULL,
  airline_count              INTEGER         NOT NULL,
  direct_route_count         INTEGER         NOT NULL,
  frequency_per_week         NUMERIC(8, 2)   NULL,
  shortest_duration_minutes  INTEGER         NOT NULL,
  longest_duration_minutes   INTEGER         NOT NULL,
  distance_km                INTEGER         NULL,
  seasonality                TEXT            NOT NULL,
  confidence_score           NUMERIC(4, 3)   NOT NULL,
  ranking_score              NUMERIC(14, 4)  NOT NULL,
  source_freshness_at        TIMESTAMPTZ     NOT NULL,
  data_version               UUID            NOT NULL,
  generated_at               TIMESTAMPTZ     NOT NULL DEFAULT now(),

  CONSTRAINT city_destination_summaries_version_key
    UNIQUE (origin_city_id, destination_city_id, data_version),

  CONSTRAINT city_destination_summaries_direction_check
    CHECK (origin_city_id <> destination_city_id),

  CONSTRAINT city_destination_summaries_counts_check
    CHECK (
      origin_airport_count > 0
      AND destination_airport_count > 0
      AND airline_count > 0
      AND direct_route_count > 0
    ),

  CONSTRAINT city_destination_summaries_duration_check
    CHECK (
      shortest_duration_minutes > 0
      AND longest_duration_minutes >= shortest_duration_minutes
    ),

  CONSTRAINT city_destination_summaries_frequency_check
    CHECK (frequency_per_week IS NULL OR frequency_per_week >= 0),

  CONSTRAINT city_destination_summaries_distance_check
    CHECK (distance_km IS NULL OR distance_km > 0),

  CONSTRAINT city_destination_summaries_seasonality_check
    CHECK (seasonality IN ('year_round', 'seasonal', 'mixed', 'unknown')),

  CONSTRAINT city_destination_summaries_confidence_check
    CHECK (confidence_score BETWEEN 0 AND 1)
);

CREATE INDEX city_destination_summaries_origin_rank_idx
ON public.city_destination_summaries USING btree (
  origin_city_id,
  data_version,
  ranking_score DESC,
  destination_city_id
);

CREATE INDEX city_destination_summaries_origin_country_idx
ON public.city_destination_summaries USING btree (
  origin_city_id,
  destination_country_id,
  data_version
);

ALTER TABLE public.city_destination_summaries ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.city_destination_summaries FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.city_destination_summaries TO service_role;
