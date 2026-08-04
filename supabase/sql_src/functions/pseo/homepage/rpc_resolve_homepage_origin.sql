-- ============================================================================
-- Function: public.rpc_resolve_homepage_origin
-- Feature: Homepage Discovery
-- Purpose: Resolve the nearest route-capable airport from visitor coordinates.
-- Responsibilities: Validate coordinates, rank eligible airports, and fall back to JFK.
-- Notes: Raw IP addresses never enter this function or the database.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_resolve_homepage_origin(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Input
  ------------------------------------------------------------------
  v_latitude DOUBLE PRECISION;
  v_longitude DOUBLE PRECISION;
  v_has_valid_coordinates BOOLEAN := FALSE;

  ------------------------------------------------------------------
  -- Resolved origin
  ------------------------------------------------------------------
  v_airport RECORD;
  v_resolution TEXT := 'fallback';
BEGIN
  -- STEP 01: Accept only finite, bounded numeric coordinate pairs.
  IF jsonb_typeof(p_input) = 'object'
    AND jsonb_typeof(p_input -> 'latitude') = 'number'
    AND jsonb_typeof(p_input -> 'longitude') = 'number'
  THEN
    v_latitude := (p_input ->> 'latitude')::DOUBLE PRECISION;
    v_longitude := (p_input ->> 'longitude')::DOUBLE PRECISION;
    v_has_valid_coordinates := v_latitude BETWEEN -90 AND 90
      AND v_longitude BETWEEN -180 AND 180;
  END IF;

  -- STEP 02: Rank active airports that can actually originate a route.
  IF v_has_valid_coordinates THEN
    SELECT
      airport.iata,
      airport.name,
      airport.latitude,
      airport.longitude,
      city.name AS city_name,
      city.slug AS city_slug,
      6371 * acos(
        LEAST(
          1,
          GREATEST(
            -1,
            cos(radians(v_latitude))
              * cos(radians(airport.latitude))
              * cos(radians(airport.longitude) - radians(v_longitude))
              + sin(radians(v_latitude))
              * sin(radians(airport.latitude))
          )
        )
      ) AS distance_km,
      (
        SELECT count(*)::INTEGER
        FROM public.route_options route_option
        WHERE route_option.origin_airport_id = airport.id
      ) AS route_count
    INTO v_airport
    FROM public.airports airport
    JOIN public.cities city
      ON city.id = airport.city_id
    WHERE airport.status = 'active'
      AND airport.iata IS NOT NULL
      AND airport.latitude IS NOT NULL
      AND airport.longitude IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.route_options route_option
        WHERE route_option.origin_airport_id = airport.id
      )
    ORDER BY distance_km, airport.iata
    LIMIT 1;

    IF FOUND THEN
      v_resolution := 'nearest';
    END IF;
  END IF;

  -- STEP 03: Use the explicit JFK fallback when geolocation cannot resolve.
  IF v_resolution = 'fallback' THEN
    SELECT
      airport.iata,
      airport.name,
      airport.latitude,
      airport.longitude,
      city.name AS city_name,
      city.slug AS city_slug,
      NULL::DOUBLE PRECISION AS distance_km,
      (
        SELECT count(*)::INTEGER
        FROM public.route_options route_option
        WHERE route_option.origin_airport_id = airport.id
      ) AS route_count
    INTO v_airport
    FROM public.airports airport
    LEFT JOIN public.cities city
      ON city.id = airport.city_id
    WHERE airport.iata = 'JFK';
  END IF;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'airport', jsonb_build_object(
        'iata', COALESCE(v_airport.iata, 'JFK'),
        'name', v_airport.name,
        'latitude', v_airport.latitude,
        'longitude', v_airport.longitude
      ),
      'city', CASE
        WHEN v_airport.city_slug IS NULL THEN NULL
        ELSE jsonb_build_object(
          'name', v_airport.city_name,
          'slug', v_airport.city_slug
        )
      END,
      'distance_km', CASE
        WHEN v_airport.distance_km IS NULL THEN NULL
        ELSE round(v_airport.distance_km::NUMERIC, 1)
      END,
      'route_count', COALESCE(v_airport.route_count, 0)
    ),
    'meta', jsonb_build_object(
      'resolution', v_resolution,
      'fallback_iata', 'JFK',
      'fallback_data_available', v_airport.iata = 'JFK'
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_resolve_homepage_origin(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_resolve_homepage_origin(JSONB) TO service_role;
