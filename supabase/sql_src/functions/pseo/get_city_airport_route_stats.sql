-- ============================================================================
-- Function: private.get_city_airport_route_stats
-- Feature: Interactive pSEO
-- Purpose: Derive reusable route coverage and airline-model statistics for city airports.
-- Responsibilities: Keep airport-card metrics version-consistent and free of editorial data.
-- Notes: Destination percentages describe distinct destination-city coverage.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.get_city_airport_route_stats(
  p_city_id UUID,
  p_data_version UUID
)
RETURNS TABLE (
  airport_id UUID,
  direct_destination_count INTEGER,
  domestic_destination_count INTEGER,
  international_destination_count INTEGER,
  domestic_destination_percentage INTEGER,
  international_destination_percentage INTEGER,
  airline_count INTEGER,
  dominant_airline_business_model TEXT
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  WITH city_context AS (
    SELECT city.country_id
    FROM public.cities city
    WHERE city.id = p_city_id
  ),
  airport_routes AS (
    SELECT
      city_route.origin_airport_id AS airport_id,
      city_route.destination_city_id,
      city_route.destination_country_id,
      city_route.operating_airline_id,
      airline.business_model,
      COALESCE(city_route.frequency_per_week, 1) AS business_model_weight
    FROM public.city_direct_routes city_route
    JOIN public.airlines airline
      ON airline.id = city_route.operating_airline_id
    WHERE city_route.origin_city_id = p_city_id
      AND city_route.data_version = p_data_version
  ),
  route_stats AS (
    SELECT
      airport_route.airport_id,
      count(DISTINCT airport_route.destination_city_id)::INTEGER AS direct_destination_count,
      count(DISTINCT airport_route.destination_city_id)
        FILTER (
          WHERE airport_route.destination_country_id = city_context.country_id
        )::INTEGER AS domestic_destination_count,
      count(DISTINCT airport_route.destination_city_id)
        FILTER (
          WHERE airport_route.destination_country_id <> city_context.country_id
        )::INTEGER AS international_destination_count,
      count(DISTINCT airport_route.operating_airline_id)::INTEGER AS airline_count
    FROM airport_routes airport_route
    CROSS JOIN city_context
    GROUP BY airport_route.airport_id
  ),
  business_model_scores AS (
    SELECT
      airport_route.airport_id,
      airport_route.business_model,
      sum(airport_route.business_model_weight) AS score
    FROM airport_routes airport_route
    GROUP BY
      airport_route.airport_id,
      airport_route.business_model
  ),
  dominant_business_models AS (
    SELECT DISTINCT ON (business_model_score.airport_id)
      business_model_score.airport_id,
      business_model_score.business_model
    FROM business_model_scores business_model_score
    ORDER BY
      business_model_score.airport_id,
      business_model_score.score DESC,
      business_model_score.business_model
  )
  SELECT
    airport.id,
    COALESCE(route_stat.direct_destination_count, 0),
    COALESCE(route_stat.domestic_destination_count, 0),
    COALESCE(route_stat.international_destination_count, 0),
    CASE
      WHEN COALESCE(route_stat.direct_destination_count, 0) = 0 THEN 0
      ELSE round(
        route_stat.domestic_destination_count::NUMERIC
        * 100
        / route_stat.direct_destination_count
      )::INTEGER
    END,
    CASE
      WHEN COALESCE(route_stat.direct_destination_count, 0) = 0 THEN 0
      ELSE round(
        route_stat.international_destination_count::NUMERIC
        * 100
        / route_stat.direct_destination_count
      )::INTEGER
    END,
    COALESCE(route_stat.airline_count, 0),
    COALESCE(dominant_business_model.business_model, 'unknown')
  FROM public.airports airport
  LEFT JOIN route_stats route_stat
    ON route_stat.airport_id = airport.id
  LEFT JOIN dominant_business_models dominant_business_model
    ON dominant_business_model.airport_id = airport.id
  WHERE airport.city_id = p_city_id
    AND airport.status = 'active';
$$;

REVOKE ALL ON FUNCTION private.get_city_airport_route_stats(UUID, UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.get_city_airport_route_stats(UUID, UUID) TO service_role;
