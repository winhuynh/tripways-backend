-- ============================================================================
-- Function: private.parse_city_page_identity
-- Feature: Interactive pSEO
-- Purpose: Validate and normalize the city-page identity shared by pSEO read RPCs.
-- Responsibilities: Validate the JSON object, city slug, and locale contract.
-- Notes: This helper does not query page data or validate RPC-specific filters.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.parse_city_page_identity(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_city_slug TEXT;
  v_locale TEXT;
  v_route_direction TEXT;
BEGIN
  IF p_input IS NULL OR jsonb_typeof(p_input) <> 'object' THEN
    RETURN jsonb_build_object(
      'data', NULL,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'Request must be a JSON object.'
      )
    );
  END IF;

  v_city_slug := lower(btrim(COALESCE(p_input->>'city_slug', '')));
  v_locale := btrim(COALESCE(p_input->>'locale', 'en-GB'));
  v_route_direction := lower(btrim(COALESCE(p_input->>'route_direction', 'outbound')));

  IF v_city_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    OR v_locale !~ '^[a-z]{2}(?:-[A-Z]{2})?$'
    OR v_route_direction NOT IN ('outbound', 'inbound')
  THEN
    RETURN jsonb_build_object(
      'data', NULL,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'City slug or locale is invalid.'
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'city_slug', v_city_slug,
      'locale', v_locale,
      'route_direction', v_route_direction
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION private.parse_city_page_identity(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.parse_city_page_identity(JSONB) TO service_role;
