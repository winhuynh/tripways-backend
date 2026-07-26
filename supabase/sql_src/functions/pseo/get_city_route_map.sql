-- ============================================================================
-- Function: private.get_city_route_map
-- Feature: Route Map
-- Purpose: Build one version-consistent city-to-city direct-route map read model.
-- Responsibilities: Filter routes, aggregate destination cities, and preserve map geometry.
-- Notes: Destination cities without coordinates are counted but omitted from rendered geometry.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.get_city_route_map(
  p_city_id UUID,
  p_city_slug TEXT,
  p_data_version UUID,
  p_origin_airports TEXT[],
  p_airlines TEXT[],
  p_destination_countries TEXT[],
  p_max_duration_minutes INTEGER,
  p_departure_window TEXT,
  p_limit INTEGER
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  WITH origin AS (
    SELECT
      city.name,
      city.slug,
      city.latitude,
      city.longitude
    FROM public.cities city
    WHERE city.id = p_city_id
  ),
  filtered AS MATERIALIZED (
    SELECT
      city_route.*,
      origin_airport.iata AS origin_airport_iata,
      destination_airport.iata AS destination_airport_iata,
      operating_airline.iata AS operating_airline_iata,
      destination_country.iso2 AS destination_country_iso2,
      destination_country.name AS destination_country_name,
      destination_city.name AS destination_city_name,
      destination_city.slug AS destination_city_slug,
      destination_city.latitude AS destination_city_latitude,
      destination_city.longitude AS destination_city_longitude
    FROM public.city_direct_routes city_route
    JOIN public.airports origin_airport
      ON origin_airport.id = city_route.origin_airport_id
    JOIN public.airports destination_airport
      ON destination_airport.id = city_route.destination_airport_id
    JOIN public.airlines operating_airline
      ON operating_airline.id = city_route.operating_airline_id
    JOIN public.countries destination_country
      ON destination_country.id = city_route.destination_country_id
    JOIN public.cities destination_city
      ON destination_city.id = city_route.destination_city_id
    WHERE city_route.origin_city_id = p_city_id
      AND city_route.data_version = p_data_version
      AND (
        cardinality(p_origin_airports) = 0
        OR origin_airport.iata = ANY(p_origin_airports)
      )
      AND (
        cardinality(p_airlines) = 0
        OR operating_airline.iata = ANY(p_airlines)
      )
      AND (
        cardinality(p_destination_countries) = 0
        OR destination_country.iso2 = ANY(p_destination_countries)
      )
      AND (
        p_max_duration_minutes IS NULL
        OR city_route.shortest_duration_minutes <= p_max_duration_minutes
      )
      AND (
        p_departure_window IS NULL
        OR (
          p_departure_window = 'morning'
          AND city_route.earliest_departure_time >= TIME '05:00'
          AND city_route.earliest_departure_time < TIME '12:00'
        )
        OR (
          p_departure_window = 'afternoon'
          AND city_route.earliest_departure_time >= TIME '12:00'
          AND city_route.earliest_departure_time < TIME '17:00'
        )
        OR (
          p_departure_window = 'evening'
          AND city_route.earliest_departure_time >= TIME '17:00'
          AND city_route.earliest_departure_time < TIME '21:00'
        )
        OR (
          p_departure_window = 'night'
          AND (
            city_route.earliest_departure_time >= TIME '21:00'
            OR city_route.earliest_departure_time < TIME '05:00'
          )
        )
      )
  ),
  destinations AS (
    SELECT
      filtered.destination_city_id,
      filtered.destination_city_name,
      filtered.destination_city_slug,
      filtered.destination_country_iso2,
      filtered.destination_country_name,
      filtered.destination_city_latitude,
      filtered.destination_city_longitude,
      jsonb_agg(
        DISTINCT filtered.origin_airport_iata
        ORDER BY filtered.origin_airport_iata
      ) AS origin_airports,
      jsonb_agg(
        DISTINCT filtered.destination_airport_iata
        ORDER BY filtered.destination_airport_iata
      ) AS destination_airports,
      jsonb_agg(
        DISTINCT filtered.operating_airline_iata
        ORDER BY filtered.operating_airline_iata
      ) AS airlines,
      CASE
        WHEN count(filtered.frequency_per_week) = 0 THEN NULL
        ELSE sum(filtered.frequency_per_week)
      END AS frequency_per_week,
      min(filtered.shortest_duration_minutes) AS shortest_duration_minutes,
      min(filtered.confidence_score) AS confidence_score
    FROM filtered
    GROUP BY
      filtered.destination_city_id,
      filtered.destination_city_name,
      filtered.destination_city_slug,
      filtered.destination_country_iso2,
      filtered.destination_country_name,
      filtered.destination_city_latitude,
      filtered.destination_city_longitude
  ),
  ranked AS (
    SELECT destinations.*
    FROM destinations
    WHERE destinations.destination_city_latitude IS NOT NULL
      AND destinations.destination_city_longitude IS NOT NULL
    ORDER BY
      COALESCE(destinations.frequency_per_week, 0) DESC,
      destinations.shortest_duration_minutes,
      destinations.confidence_score DESC,
      destinations.destination_city_name
    LIMIT p_limit
  )
  SELECT jsonb_build_object(
    'origin', (
      SELECT jsonb_build_object(
        'type', 'city',
        'name', origin.name,
        'slug', origin.slug,
        'latitude', origin.latitude,
        'longitude', origin.longitude
      )
      FROM origin
    ),
    'destinations', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'city_name', ranked.destination_city_name,
          'city_slug', ranked.destination_city_slug,
          'country_iso2', ranked.destination_country_iso2,
          'country_name', ranked.destination_country_name,
          'latitude', ranked.destination_city_latitude,
          'longitude', ranked.destination_city_longitude,
          'route_path', format(
            '/flights/%s-to-%s',
            p_city_slug,
            ranked.destination_city_slug
          ),
          'origin_airports', ranked.origin_airports,
          'destination_airports', ranked.destination_airports,
          'airlines', ranked.airlines,
          'shortest_duration_minutes', ranked.shortest_duration_minutes,
          'frequency_per_week', ranked.frequency_per_week
        )
        ORDER BY
          COALESCE(ranked.frequency_per_week, 0) DESC,
          ranked.shortest_duration_minutes,
          ranked.confidence_score DESC,
          ranked.destination_city_name
      )
      FROM ranked
    ), '[]'::JSONB),
    'total', (
      SELECT count(*)::INTEGER
      FROM destinations
    ),
    'omitted_destination_count', (
      SELECT count(*)::INTEGER
      FROM destinations
      WHERE destinations.destination_city_latitude IS NULL
        OR destinations.destination_city_longitude IS NULL
    )
  );
$$;

REVOKE ALL ON FUNCTION private.get_city_route_map(
  UUID,
  TEXT,
  UUID,
  TEXT[],
  TEXT[],
  TEXT[],
  INTEGER,
  TEXT,
  INTEGER
)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.get_city_route_map(
  UUID,
  TEXT,
  UUID,
  TEXT[],
  TEXT[],
  TEXT[],
  INTEGER,
  TEXT,
  INTEGER
) TO service_role;
