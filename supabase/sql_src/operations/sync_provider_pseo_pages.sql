-- ============================================================================
-- Function: admin.sync_provider_pseo_pages
-- Purpose: Synchronize factual pSEO source pages from canonical provider data.
-- Responsibilities: Create noindex city, airport, and fresh route source documents.
-- Notes: Generated content is never marked reviewed and cannot pass production indexing gates.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.sync_provider_pseo_pages(p_environment TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_status          TEXT;
  v_noindex_reason  TEXT;
  v_city_count      INTEGER := 0;
  v_airport_count   INTEGER := 0;
  v_route_count     INTEGER := 0;
BEGIN
  IF p_environment NOT IN ('development_fixture', 'staging', 'production') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_PUBLICATION_SOURCE_INVALID';
  END IF;

  v_status := CASE WHEN p_environment = 'development_fixture' THEN 'draft' ELSE 'published' END;
  v_noindex_reason := CASE
    WHEN p_environment = 'staging' THEN 'staging_environment'
    WHEN p_environment = 'development_fixture' THEN 'development_fixture'
    ELSE 'source_not_seo_eligible'
  END;

  -- STEP 01: Create registries for unambiguous cities with an active airport.
  INSERT INTO public.pseo_pages (
    page_type, entity_key, locale, canonical_path, display_title, status,
    is_indexable, noindex_reason, source_freshness_at
  )
  SELECT
    'city', city.slug, 'en-GB', '/flights-from-' || city.slug,
    'Flights from ' || city.name, v_status, FALSE, v_noindex_reason, city.updated_at
  FROM public.cities AS city
  WHERE EXISTS (
      SELECT 1 FROM public.airports AS airport
      WHERE airport.city_id = city.id AND airport.status = 'active'
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.cities AS duplicate
      WHERE duplicate.slug = city.slug AND duplicate.id <> city.id
    )
  ON CONFLICT (page_type, entity_key, locale) DO UPDATE
  SET source_freshness_at = EXCLUDED.source_freshness_at,
      generated_at = now();

  INSERT INTO public.city_pages (
    pseo_page_id, city_id, locale, route_direction, primary_airport_id, content,
    content_reviewed_at
  )
  SELECT
    registry.id, city.id, 'en-GB', 'outbound', airport.id,
    jsonb_build_object(
      'seo', jsonb_build_object(
        'h1', 'Flights from ' || city.name,
        'title', 'Flights from ' || city.name || ' | Tripways',
        'meta_description', 'Explore recently observed route prices from ' || city.name || '.'
      ),
      'intro', 'Explore factual airport identities and recently observed route prices from ' || city.name || '.'
    ),
    NULL
  FROM public.cities AS city
  JOIN public.pseo_pages AS registry
    ON registry.page_type = 'city' AND registry.entity_key = city.slug AND registry.locale = 'en-GB'
  JOIN LATERAL (
    SELECT candidate.id
    FROM public.airports AS candidate
    WHERE candidate.city_id = city.id AND candidate.status = 'active'
    ORDER BY
      CASE candidate.airport_type WHEN 'large_airport' THEN 1 WHEN 'medium_airport' THEN 2 ELSE 3 END,
      candidate.iata
    LIMIT 1
  ) AS airport ON TRUE
  ON CONFLICT (city_id, locale, route_direction) DO NOTHING;
  GET DIAGNOSTICS v_city_count = ROW_COUNT;

  -- STEP 02: Create registries and aggregate source documents for active airports.
  INSERT INTO public.pseo_pages (
    page_type, entity_key, locale, canonical_path, display_title, status,
    is_indexable, noindex_reason, source_freshness_at
  )
  SELECT
    'airport', lower(airport.iata), 'en-GB', '/airports/' || lower(airport.iata),
    airport.name || ' (' || airport.iata || ')', v_status, FALSE, v_noindex_reason,
    airport.updated_at
  FROM public.airports AS airport
  WHERE airport.status = 'active' AND airport.iata IS NOT NULL
  ON CONFLICT (page_type, entity_key, locale) DO UPDATE
  SET source_freshness_at = EXCLUDED.source_freshness_at,
      generated_at = now();

  INSERT INTO public.airport_pages (
    pseo_page_id, airport_id, locale, content, content_reviewed_at
  )
  SELECT
    registry.id, airport.id, 'en-GB',
    jsonb_build_object(
      'seo', jsonb_build_object(
        'h1', airport.name || ' (' || airport.iata || ')',
        'title', airport.name || ' Airport Guide | Tripways',
        'meta_description', 'View factual airport and location information for ' || airport.name || '.'
      ),
      'orientation', airport.name || ' serves ' || city.name || ', ' || country.name || '.'
    ),
    NULL
  FROM public.airports AS airport
  JOIN public.cities AS city ON city.id = airport.city_id
  JOIN public.countries AS country ON country.id = airport.country_id
  JOIN public.pseo_pages AS registry
    ON registry.page_type = 'airport'
   AND registry.entity_key = lower(airport.iata)
   AND registry.locale = 'en-GB'
  WHERE airport.status = 'active' AND airport.iata IS NOT NULL
  ON CONFLICT (airport_id, locale) DO NOTHING;
  GET DIAGNOSTICS v_airport_count = ROW_COUNT;

  -- STEP 03: Create directional route pages only from fresh provider prices.
  INSERT INTO public.pseo_pages (
    page_type, entity_key, locale, canonical_path, display_title, status,
    is_indexable, noindex_reason, source_freshness_at
  )
  SELECT
    'city_route', origin.slug || '-' || destination.slug, 'en-GB',
    '/flights/' || origin.slug || '-' || destination.slug,
    'Flights from ' || origin.name || ' to ' || destination.name,
    v_status, FALSE, v_noindex_reason, max(price.observed_at)
  FROM public.flight_route_prices AS price
  JOIN public.cities AS origin ON origin.id = price.origin_city_id
  JOIN public.cities AS destination ON destination.id = price.destination_city_id
  WHERE price.status = 'published' AND price.valid_until > now()
  GROUP BY origin.slug, origin.name, destination.slug, destination.name
  ON CONFLICT (page_type, entity_key, locale) DO UPDATE
  SET source_freshness_at = GREATEST(
        public.pseo_pages.source_freshness_at,
        EXCLUDED.source_freshness_at
      ),
      generated_at = now();

  INSERT INTO public.route_pages (
    pseo_page_id, origin_city_id, destination_city_id, locale, content,
    content_reviewed_at
  )
  SELECT DISTINCT ON (origin.id, destination.id)
    registry.id, origin.id, destination.id, 'en-GB',
    jsonb_build_object(
      'seo', jsonb_build_object(
        'h1', 'Flights from ' || origin.name || ' to ' || destination.name,
        'title', origin.name || ' to ' || destination.name || ' Flights | Tripways',
        'meta_description', 'Compare recently observed route prices from ' || origin.name || ' to ' || destination.name || '.'
      ),
      'intro', 'Compare recently observed route prices before checking current availability with the booking partner.'
    ),
    NULL
  FROM public.flight_route_prices AS price
  JOIN public.cities AS origin ON origin.id = price.origin_city_id
  JOIN public.cities AS destination ON destination.id = price.destination_city_id
  JOIN public.pseo_pages AS registry
    ON registry.page_type = 'city_route'
   AND registry.entity_key = origin.slug || '-' || destination.slug
   AND registry.locale = 'en-GB'
  WHERE price.status = 'published' AND price.valid_until > now()
  ORDER BY origin.id, destination.id, price.observed_at DESC
  ON CONFLICT (origin_city_id, destination_city_id, locale) DO NOTHING;
  GET DIAGNOSTICS v_route_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'city_pages_created', v_city_count,
    'airport_pages_created', v_airport_count,
    'route_pages_created', v_route_count
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.sync_provider_pseo_pages(TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.sync_provider_pseo_pages(TEXT) TO service_role;
