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

  DELETE FROM public.city_page_read_models WHERE publication_version_id = p_publication_version_id;
  DELETE FROM public.airport_page_read_models WHERE publication_version_id = p_publication_version_id;
  DELETE FROM public.route_page_read_models WHERE publication_version_id = p_publication_version_id;

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
    registry.entity_key,
    jsonb_set(
      private.build_city_page_payload(jsonb_build_object(
      'city_slug', registry.entity_key,
      'locale', city_page.locale,
      'route_direction', city_page.route_direction,
      'destination_limit', 20,
      'publication_version_id', p_publication_version_id
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
  JOIN public.pseo_pages AS registry ON registry.id = city_page.pseo_page_id
  WHERE city_page.route_direction = 'outbound'
    AND registry.status <> 'archived';
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
    private.build_airport_page_payload(jsonb_build_object(
      'airport_iata', airport.iata,
      'locale', airport_page.locale,
      'publication_version_id', p_publication_version_id
    ))->'data'
  FROM public.airport_pages airport_page
  JOIN public.airports airport
    ON airport.id = airport_page.airport_id
  JOIN public.pseo_pages AS registry ON registry.id = airport_page.pseo_page_id
  WHERE registry.status <> 'archived';
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
    registry.entity_key,
    private.build_route_page_payload(jsonb_build_object(
      'route_slug', registry.entity_key,
      'locale', route_page.locale,
      'publication_version_id', p_publication_version_id
    ))->'data'
  FROM public.route_pages route_page
  JOIN public.pseo_pages AS registry ON registry.id = route_page.pseo_page_id
  WHERE registry.status <> 'archived';
  GET DIAGNOSTICS v_route_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'city', v_city_count,
    'airport', v_airport_count,
    'route', v_route_count
  );
END;
$$;

REVOKE ALL ON FUNCTION private.refresh_page_read_models(UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.refresh_page_read_models(UUID) TO service_role;
