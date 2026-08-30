-- ============================================================================
-- Function: admin.classify_route_connection_type
-- Purpose: Classify itinerary type based on airline legs (direct, same-airline, alliance).
-- Responsibilities: Provide pure, reusable route connection classification logic.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.classify_route_connection_type(
  p_airline1 TEXT,
  p_airline2 TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF p_airline2 IS NULL OR NULLIF(btrim(p_airline2), '') IS NULL THEN
    RETURN 'direct';
  END IF;

  IF upper(btrim(p_airline1)) = upper(btrim(p_airline2)) THEN
    RETURN 'same_airline';
  END IF;

  RETURN 'alliance';
END;
$$;

REVOKE ALL ON FUNCTION admin.classify_route_connection_type(TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.classify_route_connection_type(TEXT, TEXT) TO service_role;
