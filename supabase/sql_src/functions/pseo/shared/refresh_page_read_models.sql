-- ============================================================================
-- Function: private.refresh_page_read_models
-- Purpose: Materialize all page-specific single-load read models for one candidate version.
-- Responsibilities: Compose bounded page payloads outside the public request path.
-- Notes: Private builders compose bounded modules only during publication.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.refresh_page_read_models(p_publication_version_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SET search_path = ''
AS $$
DECLARE
  v_homepage_count INTEGER;
  v_city_count INTEGER;
  v_airport_count INTEGER;
  v_route_count INTEGER;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.publication_versions version
    WHERE version.id = p_publication_version_id
      AND version.status = 'building'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_PUBLICATION_VERSION_INVALID';
  END IF;

  DELETE FROM public.homepage_read_models WHERE publication_version_id = p_publication_version_id;
  DELETE FROM public.city_page_read_models WHERE publication_version_id = p_publication_version_id;
  DELETE FROM public.airport_page_read_models WHERE publication_version_id = p_publication_version_id;
  DELETE FROM public.route_page_read_models WHERE publication_version_id = p_publication_version_id;

  INSERT INTO public.homepage_read_models (publication_version_id, locale, payload)
  SELECT
    p_publication_version_id,
    homepage.locale,
    jsonb_build_object(
      'page', jsonb_build_object('type', 'homepage', 'locale', homepage.locale),
      'seo', jsonb_build_object(
        'h1', homepage.h1,
        'subheadline', homepage.subheadline,
        'intro', homepage.intro,
        'title', homepage.seo_title,
        'meta_description', homepage.meta_description
      ),
      'facts', jsonb_build_object(),
      'discovery', private.build_homepage_discovery(jsonb_build_object(
        'origin', 'GLOBAL',
        'max_stops', 0,
        'limit', 20
      ))->'data',
      'content', jsonb_build_object(
        'sections', COALESCE((
          SELECT jsonb_agg(to_jsonb(section) - 'homepage_page_id' ORDER BY section.display_order)
          FROM public.homepage_content_sections section
          WHERE section.homepage_page_id = homepage.id
            AND section.locale = homepage.locale
            AND section.status = 'published'
        ), '[]'::JSONB),
        'featured_origins', COALESCE((
          SELECT jsonb_agg(to_jsonb(origin) - 'homepage_page_id' ORDER BY origin.display_order)
          FROM public.homepage_featured_origins origin
          WHERE origin.homepage_page_id = homepage.id
            AND origin.status = 'published'
        ), '[]'::JSONB),
        'featured_routes', COALESCE((
          SELECT jsonb_agg(to_jsonb(route) - 'homepage_page_id' ORDER BY route.display_order)
          FROM public.homepage_featured_routes route
          WHERE route.homepage_page_id = homepage.id
            AND route.status = 'published'
        ), '[]'::JSONB)
      ),
      'faqs', COALESCE((
        SELECT jsonb_agg(to_jsonb(faq) - 'homepage_page_id' ORDER BY faq.display_order)
        FROM public.homepage_faqs faq
        WHERE faq.homepage_page_id = homepage.id
          AND faq.locale = homepage.locale
          AND faq.status = 'published'
      ), '[]'::JSONB),
      'internal_links', '[]'::JSONB,
      'indexability', jsonb_build_object(
        'is_indexable', homepage.is_indexable,
        'noindex_reason', homepage.noindex_reason
      )
    )
  FROM public.homepage_pages homepage
  WHERE homepage.status <> 'archived';
  GET DIAGNOSTICS v_homepage_count = ROW_COUNT;

  INSERT INTO public.city_page_read_models (
    publication_version_id,
    city_id,
    locale,
    canonical_slug,
    payload
  )
  SELECT
    p_publication_version_id,
    city_page.city_id,
    city_page.locale,
    city_page.canonical_slug,
    jsonb_set(
      private.build_city_page_payload(jsonb_build_object(
      'city_slug', city_page.canonical_slug,
      'locale', city_page.locale,
      'route_direction', city_page.route_direction,
      'destination_limit', 20
      ))->'data',
      '{content_sections}',
      COALESCE((
        SELECT jsonb_agg(to_jsonb(section) - 'city_page_id' ORDER BY section.display_order)
        FROM public.city_content_sections section
        WHERE section.city_page_id = city_page.id
          AND section.locale = city_page.locale
          AND section.status = 'published'
      ), '[]'::JSONB),
      TRUE
    )
  FROM public.city_pages city_page
  WHERE city_page.route_direction = 'outbound'
    AND city_page.status <> 'archived';
  GET DIAGNOSTICS v_city_count = ROW_COUNT;

  INSERT INTO public.airport_page_read_models (
    publication_version_id,
    airport_id,
    locale,
    airport_iata,
    payload
  )
  SELECT
    p_publication_version_id,
    airport_page.airport_id,
    airport_page.locale,
    airport.iata,
    jsonb_set(
      private.build_airport_page_payload(jsonb_build_object(
      'airport_iata', airport.iata,
      'locale', airport_page.locale
      ))->'data',
      '{content_sections}',
      COALESCE((
        SELECT jsonb_agg(to_jsonb(section) - 'airport_page_id' ORDER BY section.display_order)
        FROM public.airport_content_sections section
        WHERE section.airport_page_id = airport_page.id
          AND section.locale = airport_page.locale
          AND section.status = 'published'
      ), '[]'::JSONB),
      TRUE
    )
  FROM public.airport_pages airport_page
  JOIN public.airports airport
    ON airport.id = airport_page.airport_id
  WHERE airport_page.status <> 'archived';
  GET DIAGNOSTICS v_airport_count = ROW_COUNT;

  INSERT INTO public.route_page_read_models (
    publication_version_id,
    route_page_id,
    locale,
    canonical_slug,
    payload
  )
  SELECT
    p_publication_version_id,
    route_page.id,
    route_page.locale,
    route_page.canonical_slug,
    private.build_route_page_payload(jsonb_build_object(
      'route_slug', route_page.canonical_slug,
      'locale', route_page.locale
    ))->'data'
  FROM public.route_pages route_page
  WHERE route_page.status <> 'archived';
  GET DIAGNOSTICS v_route_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'homepage', v_homepage_count,
    'city', v_city_count,
    'airport', v_airport_count,
    'route', v_route_count
  );
END;
$$;

REVOKE ALL ON FUNCTION private.refresh_page_read_models(UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.refresh_page_read_models(UUID) TO service_role;
