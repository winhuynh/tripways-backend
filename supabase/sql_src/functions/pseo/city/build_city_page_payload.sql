-- ============================================================================
-- Function: admin.build_city_page_payload
-- Purpose: Compose one public-safe City page payload for a publication candidate.
-- Responsibilities: Allowlist city identity, content, routes, and lifecycle metadata.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.build_city_page_payload(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_slug      TEXT := lower(p_input->>'city_slug');
  v_locale    TEXT := COALESCE(NULLIF(p_input->>'locale', ''), 'en-GB');
  v_direction TEXT := COALESCE(NULLIF(p_input->>'route_direction', ''), 'outbound');
  v_version   UUID := (p_input->>'publication_version_id')::UUID;
  v_page      public.city_pages%ROWTYPE;
  v_city      public.cities%ROWTYPE;
  v_country   public.countries%ROWTYPE;
  v_registry  public.pseo_pages%ROWTYPE;
BEGIN
  SELECT page.*
  INTO v_page
  FROM public.city_pages AS page
  JOIN public.pseo_pages AS registry
    ON registry.id = page.pseo_page_id
  WHERE registry.entity_key = v_slug
    AND page.locale = v_locale
    AND page.route_direction = v_direction;

  IF v_page.id IS NULL THEN
    RETURN admin.build_rpc_error(NULL, 'ERR_NOT_FOUND', 'City page not found.');
  END IF;

  SELECT * INTO v_city FROM public.cities WHERE id = v_page.city_id;
  SELECT * INTO v_country FROM public.countries WHERE id = v_city.country_id;
  SELECT * INTO v_registry FROM public.pseo_pages WHERE id = v_page.pseo_page_id;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'city', jsonb_build_object(
        'name', v_city.name,
        'slug', v_city.slug,
        'iata_code', v_city.iata_code,
        'latitude', COALESCE(v_city.latitude, (SELECT a.latitude FROM public.airports a WHERE a.city_id = v_city.id AND a.latitude IS NOT NULL ORDER BY (a.airport_type = 'large_airport') DESC, a.name ASC LIMIT 1)),
        'longitude', COALESCE(v_city.longitude, (SELECT a.longitude FROM public.airports a WHERE a.city_id = v_city.id AND a.longitude IS NOT NULL ORDER BY (a.airport_type = 'large_airport') DESC, a.name ASC LIMIT 1)),
        'timezone', COALESCE(v_city.timezone, (SELECT a.timezone FROM public.airports a WHERE a.city_id = v_city.id AND a.timezone IS NOT NULL LIMIT 1)),
        'currency_code', v_city.currency_code,
        'primary_language', v_city.primary_language
      ),
      'country', jsonb_build_object(
        'name', v_country.name,
        'slug', v_country.slug,
        'iso2', v_country.iso2,
        'region', COALESCE(v_country.region, 'Asia'),
        'subregion', v_country.subregion
      ),
      'page', jsonb_build_object(
        'h1', COALESCE(v_page.content->'seo'->>'h1', 'Direct flights from ' || v_city.name),
        'subheadline', COALESCE(v_page.content->'seo'->>'subheadline', 'Explore nonstop destinations across Asia, Europe, and beyond'),
        'seo_title', COALESCE(v_page.content->'seo'->>'title', 'Direct Flights from ' || v_city.name || ': Routes & Airlines | Tripways'),
        'meta_description', COALESCE(v_page.content->'seo'->>'meta_description', 'Explore nonstop destinations accessible from ' || v_city.name || '.'),
        'intro', COALESCE(v_page.content->'seo'->>'intro', v_page.content->>'intro', 'Explore nonstop destinations accessible from ' || v_city.name || '.')
      ),
      'airports', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'iata', a.iata,
          'name', a.name,
          'is_primary', (a.iata = v_city.iata_code OR a.airport_type = 'large_airport'),
          'direct_destinations', (
            SELECT count(DISTINCT opt.destination_airport_iata)
            FROM public.flight_route_options opt
            WHERE opt.origin_airport_iata = a.iata AND opt.publication_version_id = v_version AND opt.stops = 0
          ),
          'airlines', (
            SELECT count(DISTINCT al)
            FROM public.flight_route_options opt,
            LATERAL unnest(opt.operating_airlines) AS al
            WHERE opt.origin_airport_iata = a.iata AND opt.publication_version_id = v_version
          ),
          'hub_label', CASE WHEN a.iata = v_city.iata_code OR a.airport_type = 'large_airport' THEN 'Primary Hub' ELSE 'LCC Hub' END,
          'description', a.name || ' serving ' || v_city.name,
          'latitude', a.latitude,
          'longitude', a.longitude
        ) ORDER BY (a.iata = v_city.iata_code) DESC, a.name ASC)
        FROM public.airports a
        WHERE a.city_id = v_city.id AND a.iata IS NOT NULL
      ), '[]'::JSONB),
      'quick_facts', jsonb_build_object(
        'airports', COALESCE((SELECT count(*) FROM public.airports WHERE city_id = v_city.id AND iata IS NOT NULL), 1),
        'direct_destinations', COALESCE((
          SELECT count(DISTINCT opt.destination_city_id)
          FROM public.flight_route_options opt
          WHERE opt.origin_city_id = v_city.id AND opt.publication_version_id = v_version AND opt.stops = 0
        ), 0),
        'direct_countries', COALESCE((
          SELECT count(DISTINCT dest_city.country_id)
          FROM public.flight_route_options opt
          JOIN public.cities dest_city ON dest_city.id = opt.destination_city_id
          WHERE opt.origin_city_id = v_city.id AND opt.publication_version_id = v_version AND opt.stops = 0
        ), 0),
        'airlines', COALESCE((
          SELECT count(DISTINCT al)
          FROM public.flight_route_options opt,
          LATERAL unnest(opt.operating_airlines) AS al
          WHERE opt.origin_city_id = v_city.id AND opt.publication_version_id = v_version
        ), 0)
      ),
      'featured_destinations', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'city', jsonb_build_object(
            'name', fd.city_name,
            'slug', fd.city_slug,
            'latitude', fd.latitude,
            'longitude', fd.longitude
          ),
          'country', jsonb_build_object(
            'name', fd.country_name,
            'slug', fd.country_slug,
            'region', fd.region
          ),
          'origin_airports', fd.origin_airports,
          'destination_airports', fd.destination_airports,
          'airlines', fd.airlines,
          'stops', fd.stops,
          'layover_airports', fd.layover_airports,
          'duration_minutes', fd.duration_minutes,
          'route_path', fd.route_path,
          'is_top_route', (fd.rn = 1),
          'latitude', fd.latitude,
          'longitude', fd.longitude
        ) ORDER BY fd.stops ASC, fd.confidence_score DESC, fd.opt_id)
        FROM (
          SELECT
            opt.id AS opt_id,
            opt.stops,
            opt.confidence_score,
            dest_c.name AS city_name,
            dest_c.slug AS city_slug,
            dest_c.latitude,
            dest_c.longitude,
            dest_co.name AS country_name,
            dest_co.slug AS country_slug,
            COALESCE(dest_co.subregion, dest_co.region, 'Asia') AS region,
            ARRAY[opt.origin_airport_iata] AS origin_airports,
            ARRAY[opt.destination_airport_iata] AS destination_airports,
            opt.operating_airlines AS airlines,
            opt.layover_airports,
            opt.total_duration_minutes AS duration_minutes,
            opt.route_path,
            row_number() OVER (ORDER BY opt.stops ASC, opt.confidence_score DESC) AS rn
          FROM public.flight_route_options opt
          JOIN public.cities dest_c ON dest_c.id = opt.destination_city_id
          JOIN public.countries dest_co ON dest_co.id = dest_c.country_id
          WHERE opt.publication_version_id = v_version
            AND opt.origin_city_id = v_city.id
        ) fd
      ), '[]'::JSONB),
      'faqs', COALESCE(v_page.content->'faqs', '[]'::JSONB),
      'internal_link_groups', COALESCE(v_page.content->'internal_link_groups', '[]'::JSONB),
      'flight_data_state', CASE
        WHEN EXISTS (
          SELECT 1
          FROM public.flight_route_options AS option
          WHERE option.publication_version_id = v_version
            AND (
              (v_direction = 'outbound' AND option.origin_city_id = v_city.id)
              OR (v_direction = 'inbound' AND option.destination_city_id = v_city.id)
            )
        ) THEN 'available'
        ELSE 'loading'
      END,

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
            (v_direction = 'outbound' AND option.origin_city_id = v_city.id)
            OR (v_direction = 'inbound' AND option.destination_city_id = v_city.id)
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

REVOKE ALL ON FUNCTION admin.build_city_page_payload(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.build_city_page_payload(JSONB) TO service_role;
