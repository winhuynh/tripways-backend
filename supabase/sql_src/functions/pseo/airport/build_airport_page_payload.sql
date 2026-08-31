-- ============================================================================
-- Function: admin.build_airport_page_payload
-- Purpose: Compose one public-safe Airport page payload for a publication candidate.
-- Responsibilities: Allowlist airport identity, content, routes, and lifecycle metadata.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.build_airport_page_payload(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_iata     TEXT := upper(p_input->>'airport_iata');
  v_locale   TEXT := COALESCE(NULLIF(p_input->>'locale', ''), 'en-GB');
  v_version  UUID := (p_input->>'publication_version_id')::UUID;
  v_page     public.airport_pages%ROWTYPE;
  v_airport  public.airports%ROWTYPE;
  v_registry public.pseo_pages%ROWTYPE;
BEGIN
  SELECT page.*
  INTO v_page
  FROM public.airport_pages AS page
  JOIN public.airports AS airport
    ON airport.id = page.airport_id
  WHERE airport.iata = v_iata
    AND page.locale = v_locale;

  IF v_page.id IS NULL THEN
    RETURN admin.build_rpc_error(NULL, 'ERR_NOT_FOUND', 'Airport page not found.');
  END IF;

  SELECT * INTO v_airport FROM public.airports WHERE id = v_page.airport_id;
  SELECT * INTO v_registry FROM public.pseo_pages WHERE id = v_page.pseo_page_id;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'airport', jsonb_build_object(
        'iata', v_airport.iata,
        'icao', v_airport.icao,
        'name', v_airport.name,
        'slug', v_airport.slug,
        'image_path', v_airport.image_path,
        'timezone', v_airport.timezone,
        'latitude', v_airport.latitude,
        'longitude', v_airport.longitude
      ),
      'content', v_page.content,
      'routes', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'from', option.origin_airport_iata,
          'to', option.destination_airport_iata,
          'stops', option.stops,
          'layover_airports', option.layover_airports,
          'operating_airlines', option.operating_airlines,
          'flight_numbers', option.flight_numbers,
          'total_duration_minutes', option.total_duration_minutes,
          'total_distance_km', option.total_distance_km,
          'days_of_week', option.days_of_week,
          'route_type', option.route_type,
          'route_path', option.route_path
        ) ORDER BY option.stops ASC, option.total_duration_minutes ASC, option.confidence_score DESC, option.id)
        FROM public.flight_route_options AS option
        WHERE option.publication_version_id = v_version
          AND (
            option.origin_airport_id = v_airport.id
            OR option.destination_airport_id = v_airport.id
          )
      ), '[]'::JSONB)
    ),
    'meta', jsonb_build_object(
      'canonical_path', v_registry.canonical_path,
      'is_indexable', v_registry.is_indexable,
      'noindex_reason', v_registry.noindex_reason,
      'data_version', 'v_' || md5(v_version::TEXT),
      'source_freshness_at', v_registry.source_freshness_at
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.build_airport_page_payload(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.build_airport_page_payload(JSONB) TO service_role;
