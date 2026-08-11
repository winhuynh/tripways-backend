-- ============================================================================
-- Function: private.generate_local_geo_preview_pages
-- Purpose: Build local-only draft/noindex City and Airport pages from base data.
-- Notes: Ambiguous city slugs are intentionally skipped until disambiguated.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.generate_local_geo_preview_pages()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_city_registry_count INTEGER := 0;
  v_city_page_count INTEGER := 0;
  v_airport_registry_count INTEGER := 0;
  v_airport_page_count INTEGER := 0;
  v_route_page_count INTEGER := 0;
  v_ambiguous_city_count INTEGER := 0;
BEGIN
  SELECT count(*)
  INTO v_ambiguous_city_count
  FROM (
    SELECT city.slug
    FROM public.cities AS city
    GROUP BY city.slug
    HAVING count(*) > 1
  ) AS ambiguous;

  INSERT INTO public.pseo_pages (
    page_type,
    entity_key,
    locale,
    canonical_path,
    display_title,
    status,
    is_indexable,
    noindex_reason,
    source_freshness_at
  )
  SELECT
    'city',
    city.slug,
    'en-GB',
    '/flights-from/' || city.slug,
    'Direct flights from ' || city.name,
    'draft',
    FALSE,
    'development_preview',
    city.updated_at
  FROM public.cities AS city
  WHERE NOT EXISTS (
      SELECT 1
      FROM public.cities AS duplicate
      WHERE duplicate.slug = city.slug
        AND duplicate.id <> city.id
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.city_pages AS city_page
      WHERE city_page.city_id = city.id
        AND city_page.locale = 'en-GB'
        AND city_page.route_direction = 'outbound'
    )
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_city_registry_count = ROW_COUNT;

  INSERT INTO public.city_pages (
    pseo_page_id,
    city_id,
    locale,
    route_direction,
    h1,
    subheadline,
    seo_title,
    meta_description,
    og_title,
    og_description,
    intro,
    airport_summary,
    primary_airport_id,
    content_reviewed_at
  )
  SELECT
    registry.id,
    city.id,
    'en-GB',
    'outbound',
    'Direct flights from ' || city.name,
    'Explore commercial airports and available flight connections from ' || city.name || ', ' || country.name || '.',
    'Direct Flights from ' || city.name || ' | Tripways',
    'Explore commercial airports and flight connections from ' || city.name || ', ' || country.name || '.',
    'Direct flights from ' || city.name,
    'Explore airports and flight connections from ' || city.name || ', ' || country.name || '.',
    city.name || ' is served by the commercial airport data listed below. Route schedules and fares are shown only when available.',
    CASE
      WHEN airport_rollup.airport_count = 1 THEN city.name || ' has 1 commercial airport in the current dataset.'
      ELSE city.name || ' has ' || airport_rollup.airport_count || ' commercial airports in the current dataset.'
    END,
    airport_rollup.primary_airport_id,
    NULL
  FROM public.cities AS city
  JOIN public.countries AS country ON country.id = city.country_id
  JOIN public.pseo_pages AS registry
    ON registry.page_type = 'city'
   AND registry.entity_key = city.slug
   AND registry.locale = 'en-GB'
  CROSS JOIN LATERAL (
    SELECT
      count(*)::INTEGER AS airport_count,
      (array_agg(airport.id ORDER BY
        CASE airport.airport_type WHEN 'large_airport' THEN 1 WHEN 'medium_airport' THEN 2 ELSE 3 END,
        airport.iata
      ))[1] AS primary_airport_id
    FROM public.airports AS airport
    WHERE airport.city_id = city.id
      AND airport.iata IS NOT NULL
      AND airport.status = 'active'
  ) AS airport_rollup
  WHERE airport_rollup.airport_count > 0
    AND NOT EXISTS (
      SELECT 1 FROM public.cities AS duplicate
      WHERE duplicate.slug = city.slug AND duplicate.id <> city.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.city_pages AS existing
      WHERE existing.city_id = city.id
        AND existing.locale = 'en-GB'
        AND existing.route_direction = 'outbound'
    )
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_city_page_count = ROW_COUNT;

  INSERT INTO public.pseo_pages (
    page_type,
    entity_key,
    locale,
    canonical_path,
    display_title,
    status,
    is_indexable,
    noindex_reason,
    source_freshness_at
  )
  SELECT
    'airport',
    lower(airport.iata),
    'en-GB',
    '/airports/' || airport.slug || '-' || lower(airport.iata),
    airport.name || ' (' || airport.iata || ')',
    'draft',
    FALSE,
    'development_preview',
    airport.updated_at
  FROM public.airports AS airport
  WHERE airport.iata IS NOT NULL
    AND airport.city_id IS NOT NULL
    AND airport.status = 'active'
    AND NOT EXISTS (
      SELECT 1
      FROM public.airport_pages AS airport_page
      WHERE airport_page.airport_id = airport.id
        AND airport_page.locale = 'en-GB'
    )
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_airport_registry_count = ROW_COUNT;

  INSERT INTO public.airport_pages (
    pseo_page_id,
    airport_id,
    locale,
    h1,
    subheadline,
    seo_title,
    meta_description,
    og_title,
    og_description,
    intro,
    orientation_summary,
    arrival_summary,
    departure_summary,
    primary_city_area_label,
    content_reviewed_at
  )
  SELECT
    registry.id,
    airport.id,
    'en-GB',
    airport.name || ' (' || airport.iata || ')',
    'Airport information for ' || city.name || ', ' || country.name || '.',
    airport.name || ' (' || airport.iata || ') Guide | Tripways',
    'View location, city, timezone and available flight information for ' || airport.name || ' (' || airport.iata || ').',
    airport.name || ' (' || airport.iata || ')',
    'Airport information for ' || airport.name || ' serving ' || city.name || '.',
    airport.name || ' is a commercial airport serving ' || city.name || ', ' || country.name || '.',
    'Use this preview for the airport identity, location and available route data currently stored by Tripways.',
    'Arrival transport details are awaiting editorial review.',
    'Departure and terminal details are awaiting editorial review.',
    city.name,
    NULL
  FROM public.airports AS airport
  JOIN public.cities AS city ON city.id = airport.city_id
  JOIN public.countries AS country ON country.id = airport.country_id
  JOIN public.pseo_pages AS registry
    ON registry.page_type = 'airport'
   AND registry.entity_key = lower(airport.iata)
   AND registry.locale = 'en-GB'
  WHERE airport.iata IS NOT NULL
    AND airport.status = 'active'
    AND NOT EXISTS (
      SELECT 1 FROM public.airport_pages AS existing
      WHERE existing.airport_id = airport.id
        AND existing.locale = 'en-GB'
    )
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_airport_page_count = ROW_COUNT;

  INSERT INTO public.route_pages (
    pseo_page_id,
    origin_city_id,
    destination_city_id,
    locale,
    h1,
    subheadline,
    seo_title,
    meta_description,
    intro,
    content_reviewed_at
  )
  SELECT
    registry.id,
    origin_city.id,
    destination_city.id,
    'en-GB',
    'Flights from ' || origin_city.name || ' to ' || destination_city.name,
    'Explore stored direct flight options from ' || origin_city.name || ' to ' || destination_city.name || '.',
    origin_city.name || ' to ' || destination_city.name || ' Flights | Tripways',
    'Explore airlines, airports and stored flight options from ' || origin_city.name || ' to ' || destination_city.name || '.',
    'Compare the route data currently available for travel from ' || origin_city.name || ' to ' || destination_city.name || '.',
    NULL
  FROM public.pseo_pages AS registry
  JOIN public.cities AS origin_city
    ON origin_city.slug = split_part(registry.entity_key, ':', 1)
  JOIN public.cities AS destination_city
    ON destination_city.slug = split_part(registry.entity_key, ':', 2)
  WHERE registry.page_type = 'city_route'
    AND registry.locale = 'en-GB'
    AND registry.entity_key LIKE '%:%'
    AND NOT EXISTS (
      SELECT 1 FROM public.route_pages AS existing
      WHERE existing.pseo_page_id = registry.id
    )
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_route_page_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'city_registry_created', v_city_registry_count,
    'city_pages_created', v_city_page_count,
    'airport_registry_created', v_airport_registry_count,
    'airport_pages_created', v_airport_page_count,
    'route_pages_created', v_route_page_count,
    'ambiguous_city_slugs_skipped', v_ambiguous_city_count
  );
END;
$$;

REVOKE ALL ON FUNCTION private.generate_local_geo_preview_pages()
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.generate_local_geo_preview_pages() TO service_role;
