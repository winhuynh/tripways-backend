-- ============================================================================
-- Function: private.normalize_airport_iata
-- Feature: Shared RPC validation
-- Purpose: Normalize and validate one airport IATA code.
-- Responsibilities: Trim input, uppercase valid codes, and reject malformed values.
-- Notes: NULL represents invalid or missing input.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.normalize_airport_iata(p_value TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
STRICT
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN upper(btrim(p_value)) ~ '^[A-Z]{3}$'
      THEN upper(btrim(p_value))
    ELSE NULL
  END;
$$;

REVOKE ALL ON FUNCTION private.normalize_airport_iata(TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.normalize_airport_iata(TEXT) TO service_role;
