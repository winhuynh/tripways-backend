-- Search only entities present in the currently published canonical projection.
CREATE OR REPLACE FUNCTION public.rpc_search_places(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_query TEXT := lower(btrim(COALESCE(p_input ->> 'query', '')));
  v_locale TEXT := COALESCE(NULLIF(p_input ->> 'locale', ''), 'en-GB');
  v_limit INTEGER := COALESCE((p_input ->> 'limit')::INTEGER, 8);
  v_version_id UUID;
BEGIN
  IF char_length(v_query) < 1 OR v_limit NOT BETWEEN 1 AND 20 THEN
    RETURN private.build_rpc_error(NULL, 'ERR_INVALID_REQUEST', 'Invalid place search.');
  END IF;

  SELECT version.id INTO v_version_id
  FROM public.publication_versions AS version
  WHERE version.is_current = TRUE AND version.status = 'published';

  RETURN jsonb_build_object(
    'data', COALESCE((
      SELECT jsonb_agg(to_jsonb(result) ORDER BY result.rank_score DESC, result.name)
      FROM (
        SELECT * FROM (
          SELECT DISTINCT ON (city.id)
            'city'::TEXT AS entity_type,
            city.id,
            city.name,
            option.origin_city_slug AS code,
            option.origin_city_slug AS slug,
            CASE WHEN option.origin_city_slug = v_query THEN 2 ELSE 1 END::NUMERIC AS rank_score
          FROM public.flight_route_options AS option
          JOIN public.cities AS city ON city.id = option.origin_city_id
          WHERE option.publication_version_id = v_version_id
            AND (lower(city.name) LIKE '%' || v_query || '%'
              OR option.origin_city_slug LIKE '%' || v_query || '%')
          ORDER BY city.id, option.origin_city_slug
        ) AS cities
        UNION ALL
        SELECT * FROM (
          SELECT DISTINCT ON (airport.id)
            'airport'::TEXT,
            airport.id,
            airport.name,
            airport.iata,
            lower(airport.iata),
            CASE WHEN lower(airport.iata) = v_query THEN 2 ELSE 1 END::NUMERIC
          FROM public.flight_route_options AS option
          JOIN public.airports AS airport ON airport.id = option.origin_airport_id
          WHERE option.publication_version_id = v_version_id
            AND (lower(airport.name) LIKE '%' || v_query || '%'
              OR lower(airport.iata) LIKE v_query || '%')
          ORDER BY airport.id
        ) AS airports
      ) AS result
      LIMIT v_limit
    ), '[]'::JSONB),
    'meta', jsonb_build_object(
      'query', v_query,
      'locale', v_locale,
      'limit', v_limit,
      'data_version', v_version_id
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_places(JSONB) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_search_places(JSONB) TO service_role;
