-- ============================================================================
-- Function: private.resolve_airport_page_context
-- Feature: Interactive pSEO
-- Purpose: Resolve normalized airport and localized page identity.
-- Responsibilities: Return IDs and the current published read-model version.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.resolve_airport_page_context(
  p_airport_iata TEXT,
  p_locale TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_airport_id UUID;
  v_city_id UUID;
  v_country_id UUID;
  v_airport_page_id UUID;
  v_pseo_page_id UUID;
BEGIN
  SELECT
    airport.id,
    airport.city_id,
    airport.country_id
  INTO
    v_airport_id,
    v_city_id,
    v_country_id
  FROM public.airports airport
  WHERE airport.iata = p_airport_iata;

  IF v_airport_id IS NULL THEN
    RETURN jsonb_build_object(
      'data', NULL,
      'error', jsonb_build_object(
        'code', 'ERR_AIRPORT_NOT_FOUND',
        'message', 'Airport was not found.'
      )
    );
  END IF;

  SELECT
    airport_page.id,
    airport_page.pseo_page_id
  INTO
    v_airport_page_id,
    v_pseo_page_id
  FROM public.airport_pages airport_page
  WHERE airport_page.airport_id = v_airport_id
    AND airport_page.locale = p_locale;

  IF v_airport_page_id IS NULL THEN
    RETURN jsonb_build_object(
      'data', NULL,
      'error', jsonb_build_object(
        'code', 'ERR_AIRPORT_PAGE_NOT_FOUND',
        'message', 'Airport page was not found.'
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'airport_id', v_airport_id,
      'airport_page_id', v_airport_page_id,
      'pseo_page_id', v_pseo_page_id,
      'city_id', v_city_id,
      'country_id', v_country_id
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION private.resolve_airport_page_context(TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.resolve_airport_page_context(TEXT, TEXT) TO service_role;
