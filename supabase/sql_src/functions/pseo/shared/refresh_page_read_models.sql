-- ============================================================================
-- Function: private.refresh_page_read_models
-- Purpose: Materialize all page-specific single-load read models for one candidate version.
-- Responsibilities: Compose bounded page payloads outside the public request path.
-- Notes: Existing page RPCs act as offline page composers until their source modules are split.
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
  VALUES (
    p_publication_version_id,
    'en-GB',
    public.rpc_get_homepage_discovery(jsonb_build_object('origin', 'GLOBAL', 'max_stops', 3, 'limit', 20))->'data'
  );
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
    public.rpc_get_city_page(jsonb_build_object(
      'city_slug', city_page.canonical_slug,
      'locale', city_page.locale,
      'route_direction', city_page.route_direction,
      'destination_limit', 20
    ))->'data'
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
    public.rpc_get_airport_page(jsonb_build_object(
      'airport_iata', airport.iata,
      'locale', airport_page.locale,
      'route_limit', 20
    ))->'data'
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
    public.rpc_get_route_page(jsonb_build_object(
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
