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
  v_data_version UUID;
BEGIN
  SELECT city.id
  INTO v_city_id
  FROM public.cities city
  WHERE city.slug = p_city_slug;

  IF v_city_id IS NULL THEN
    RETURN jsonb_build_object(
      'data', NULL,
      'error', jsonb_build_object(
        'code', 'ERR_CITY_NOT_FOUND',
        'message', 'City was not found.'
      )
    );
  END IF;

  SELECT
    city_page.id,
    city_page.pseo_page_id,
    city_page.data_version
  INTO
    v_city_page_id,
    v_pseo_page_id,
    v_data_version
  FROM public.city_pages city_page
  WHERE city_page.city_id = v_city_id
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
      'data_version', v_data_version,
      'route_direction', p_route_direction
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION private.resolve_city_page_context(TEXT, TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.resolve_city_page_context(TEXT, TEXT, TEXT) TO service_role;
