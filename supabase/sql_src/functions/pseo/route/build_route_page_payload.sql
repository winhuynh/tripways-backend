-- ============================================================================
-- Function: admin.build_route_page_payload
-- Purpose: Compose one public-safe Route page payload for a publication candidate.
-- Responsibilities: Allowlist route identity, observations, pre-computed route options, and metadata.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.build_route_page_payload(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_locale   TEXT := COALESCE(NULLIF(p_input->>'locale', ''), 'en-GB');
  v_page     public.route_pages%ROWTYPE;
  v_registry public.pseo_pages%ROWTYPE;
  v_version  UUID := (p_input->>'publication_version_id')::UUID;
BEGIN
  SELECT page.*
  INTO v_page
  FROM public.route_pages AS page
  JOIN public.pseo_pages AS registry
    ON registry.id = page.pseo_page_id
  WHERE registry.entity_key = lower(p_input->>'route_slug')
    AND page.locale = v_locale;

  IF v_page.id IS NULL THEN
    RETURN admin.build_rpc_error(NULL, 'ERR_NOT_FOUND', 'Route page not found.');
  END IF;

  SELECT * INTO v_registry FROM public.pseo_pages WHERE id = v_page.pseo_page_id;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'route', jsonb_build_object(
        'origin', (
          SELECT jsonb_build_object(
            'name', city.name,
            'slug', city.slug,
            'iata_code', city.iata_code,
            'latitude', COALESCE(city.latitude, (SELECT a.latitude FROM public.airports a WHERE a.city_id = city.id AND a.latitude IS NOT NULL ORDER BY (a.airport_type = 'large_airport') DESC, a.name ASC LIMIT 1)),
            'longitude', COALESCE(city.longitude, (SELECT a.longitude FROM public.airports a WHERE a.city_id = city.id AND a.longitude IS NOT NULL ORDER BY (a.airport_type = 'large_airport') DESC, a.name ASC LIMIT 1))
          )
          FROM public.cities AS city
          WHERE city.id = v_page.origin_city_id
        ),
        'destination', (
          SELECT jsonb_build_object(
            'name', city.name,
            'slug', city.slug,
            'iata_code', city.iata_code,
            'latitude', COALESCE(city.latitude, (SELECT a.latitude FROM public.airports a WHERE a.city_id = city.id AND a.latitude IS NOT NULL ORDER BY (a.airport_type = 'large_airport') DESC, a.name ASC LIMIT 1)),
            'longitude', COALESCE(city.longitude, (SELECT a.longitude FROM public.airports a WHERE a.city_id = city.id AND a.longitude IS NOT NULL ORDER BY (a.airport_type = 'large_airport') DESC, a.name ASC LIMIT 1))
          )
          FROM public.cities AS city
          WHERE city.id = v_page.destination_city_id
        )
      ),
      'content', v_page.content,
      'flight_data_state', CASE
        WHEN EXISTS (
          SELECT 1
          FROM public.flight_route_options AS option
          WHERE option.publication_version_id = v_version
            AND option.origin_city_id = v_page.origin_city_id
            AND option.destination_city_id = v_page.destination_city_id
        ) THEN 'available'
        ELSE 'loading'
      END,

      'route_options', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'from', option.origin_airport_iata,
          'to', option.destination_airport_iata,
          'stops', option.stops,
          'layover_airports', option.layover_airports,
          'operating_airlines', option.operating_airlines,
          'flight_numbers', option.flight_numbers,
          'flight_durations_minutes', option.flight_durations_minutes,
          'total_duration_minutes', option.total_duration_minutes,
          'total_distance_km', option.total_distance_km,
          'days_of_week', option.days_of_week,
          'route_type', option.route_type,
          'confidence_score', option.confidence_score
        ) ORDER BY option.stops ASC, option.total_duration_minutes ASC, option.confidence_score DESC, option.id)
        FROM public.flight_route_options AS option
        WHERE option.publication_version_id = v_version
          AND option.origin_city_id = v_page.origin_city_id
          AND option.destination_city_id = v_page.destination_city_id
      ), '[]'::JSONB),
      'observations', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'observation_ref', item.public_reference,
          'observed_amount', item.observed_amount,
          'currency_code', item.currency_code,
          'departure_date', item.departure_date,
          'direct', item.direct,
          'observed_at', item.observed_at,
          'valid_until', item.valid_until
        ) ORDER BY item.observed_amount NULLS LAST, item.observed_at DESC)
        FROM public.flight_route_prices AS item
        JOIN admin.data_sources AS source
          ON source.id = item.source_id
        WHERE item.origin_city_id = v_page.origin_city_id
          AND item.destination_city_id = v_page.destination_city_id
          AND item.status = 'published'
          AND item.valid_until > now()
          AND source.production_display_allowed
      ), '[]'::JSONB),
      'disclosure', 'Cached observations are not live offers; final price and availability are confirmed by the booking partner.'
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

REVOKE ALL ON FUNCTION admin.build_route_page_payload(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.build_route_page_payload(JSONB) TO service_role;
