-- ============================================================================
-- Function: private.resolve_city_page_context
-- Feature: Interactive pSEO
-- Purpose: Resolve the reviewed city-page identity shared by pSEO read RPCs.
-- Responsibilities: Resolve city, city page, pSEO page, and published data version identifiers.
-- Notes: Inputs must already be normalized by private.parse_city_page_identity.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.resolve_city_page_context(
  p_city_slug TEXT,
  p_locale TEXT,
  p_route_direction TEXT DEFAULT 'outbound'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_city_id UUID;
  v_city_page_id UUID;
  v_pseo_page_id UUID;
BEGIN
  SELECT
    city_page.city_id,
    city_page.id,
    city_page.pseo_page_id
  INTO
    v_city_id,
    v_city_page_id,
    v_pseo_page_id
  FROM public.city_pages AS city_page
  JOIN public.pseo_pages AS registry
    ON registry.id = city_page.pseo_page_id
  WHERE registry.entity_key = p_city_slug
    AND registry.page_type = 'city'
    AND city_page.locale = p_locale
    AND city_page.route_direction = p_route_direction;

  IF v_city_page_id IS NULL THEN
    RETURN jsonb_build_object(
      'data', NULL,
      'error', jsonb_build_object(
        'code', 'ERR_CITY_PAGE_NOT_FOUND',
        'message', 'City page was not found.'
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'city_id', v_city_id,
      'city_page_id', v_city_page_id,
      'pseo_page_id', v_pseo_page_id,
      'route_direction', p_route_direction
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION private.resolve_city_page_context(TEXT, TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.resolve_city_page_context(TEXT, TEXT, TEXT) TO service_role;
