-- ============================================================================
-- Function: public.rpc_suggest_locations
-- Purpose: Autocomplete and suggest airports / cities / nearby hubs by prefix or geo radius.
-- Responsibilities: Provide low-latency location suggestions for the flight search bar.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_suggest_locations(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_query TEXT;
  v_origin_iata TEXT;
  v_radius_km NUMERIC;
  v_limit INTEGER;
  v_origin_lat DOUBLE PRECISION;
  v_origin_lon DOUBLE PRECISION;
  v_origin_city TEXT;
  v_origin_country TEXT;
  v_result JSONB;
BEGIN
  IF jsonb_typeof(p_input) IS DISTINCT FROM 'object' THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid location suggest request.');
  END IF;

  v_query := NULLIF(btrim(COALESCE(p_input->>'query', '')), '');
  v_origin_iata := upper(NULLIF(btrim(COALESCE(p_input->>'origin_iata', '')), ''));
  v_radius_km := COALESCE((p_input->>'radius_km')::NUMERIC, 300);
  v_limit := LEAST(GREATEST(COALESCE((p_input->>'limit')::INTEGER, 10), 1), 50);

  -- Retrieve origin airport coordinates if origin_iata is specified
  IF v_origin_iata IS NOT NULL THEN
    SELECT a.latitude, a.longitude, c.name, co.name
    INTO v_origin_lat, v_origin_lon, v_origin_city, v_origin_country
    FROM public.airports a
    LEFT JOIN public.cities c ON c.id = a.city_id
    JOIN public.countries co ON co.id = a.country_id
    WHERE a.iata = v_origin_iata
    LIMIT 1;
  END IF;

  -- 1. If query is empty and origin is provided -> list origin and nearby airports within radius
  IF v_query IS NULL AND v_origin_lat IS NOT NULL AND v_origin_lon IS NOT NULL THEN
    WITH calculated AS (
      SELECT
        a.iata,
        a.name AS airport_name,
        COALESCE(c.name, a.name) AS city_name,
        c.slug AS city_slug,
        co.name AS country_name,
        co.iso2 AS country_iso2,
        a.latitude,
        a.longitude,
        CASE
          WHEN a.iata = v_origin_iata THEN 0
          ELSE (
            6371 * 2 * asin(
              sqrt(
                power(sin(radians(a.latitude - v_origin_lat) / 2), 2) +
                cos(radians(v_origin_lat)) * cos(radians(a.latitude)) *
                power(sin(radians(a.longitude - v_origin_lon) / 2), 2)
              )
            )
          )
        END AS distance_km
      FROM public.airports a
      LEFT JOIN public.cities c ON c.id = a.city_id
      JOIN public.countries co ON co.id = a.country_id
      WHERE a.iata IS NOT NULL
        AND a.latitude IS NOT NULL
        AND a.longitude IS NOT NULL
        AND a.status = 'active'
    ),
    nearby_filtered AS (
      SELECT *
      FROM calculated
      WHERE distance_km <= v_radius_km
      ORDER BY distance_km ASC
      LIMIT v_limit
    )
    SELECT jsonb_build_object(
      'data', COALESCE(jsonb_agg(jsonb_build_object(
        'type', 'airport',
        'iata', iata,
        'name', airport_name,
        'city_name', city_name,
        'city_slug', city_slug,
        'country_name', country_name,
        'country_iso2', country_iso2,
        'distance_km', round(distance_km::numeric),
        'subtitle', CASE
          WHEN distance_km = 0 THEN country_name
          ELSE round(distance_km::numeric)::text || ' km from ' || v_origin_city || ', ' || v_origin_country
        END,
        'latitude', latitude,
        'longitude', longitude
      )), '[]'::JSONB)
    ) INTO v_result
    FROM nearby_filtered;

    RETURN v_result;
  END IF;

  -- 2. If query is provided -> prefix and substring search on IATA, City, Airport, Country
  WITH airport_matches AS (
    SELECT
      a.iata,
      a.name AS airport_name,
      COALESCE(c.name, a.name) AS city_name,
      c.slug AS city_slug,
      co.name AS country_name,
      co.iso2 AS country_iso2,
      a.latitude,
      a.longitude,
      CASE
        WHEN a.iata ILIKE v_query || '%' THEN 1
        WHEN c.name ILIKE v_query || '%' THEN 2
        WHEN a.name ILIKE v_query || '%' THEN 3
        ELSE 4
      END AS match_rank
    FROM public.airports a
    LEFT JOIN public.cities c ON c.id = a.city_id
    JOIN public.countries co ON co.id = a.country_id
    WHERE a.iata IS NOT NULL
      AND a.status = 'active'
      AND (
        a.iata ILIKE '%' || v_query || '%'
        OR a.name ILIKE '%' || v_query || '%'
        OR c.name ILIKE '%' || v_query || '%'
        OR co.name ILIKE '%' || v_query || '%'
      )
    ORDER BY match_rank ASC, a.name ASC
    LIMIT v_limit
  )
  SELECT jsonb_build_object(
    'data', COALESCE(jsonb_agg(jsonb_build_object(
      'type', 'airport',
      'iata', iata,
      'name', airport_name,
      'city_name', city_name,
      'city_slug', city_slug,
      'country_name', country_name,
      'country_iso2', country_iso2,
      'subtitle', country_name,
      'latitude', latitude,
      'longitude', longitude
    )), '[]'::JSONB)
  ) INTO v_result
  FROM airport_matches;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_suggest_locations(JSONB) FROM public;
GRANT EXECUTE ON FUNCTION public.rpc_suggest_locations(JSONB) TO anon, authenticated, service_role;
