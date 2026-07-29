-- ============================================================================
-- Function: private.parse_airport_page_identity
-- Feature: Interactive pSEO
-- Purpose: Validate and normalize airport-page identity for public read RPCs.
-- Responsibilities: Validate JSON input, IATA code, and locale.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.parse_airport_page_identity(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_airport_iata TEXT;
  v_locale TEXT;
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

  v_airport_iata := upper(btrim(COALESCE(p_input->>'airport_iata', '')));
  v_locale := btrim(COALESCE(p_input->>'locale', 'en-GB'));

  IF v_airport_iata !~ '^[A-Z]{3}$'
    OR v_locale !~ '^[a-z]{2}(?:-[A-Z]{2})?$'
  THEN
    RETURN jsonb_build_object(
      'data', NULL,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'Airport IATA code or locale is invalid.'
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'airport_iata', v_airport_iata,
      'locale', v_locale
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION private.parse_airport_page_identity(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.parse_airport_page_identity(JSONB) TO service_role;
