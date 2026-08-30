-- ============================================================================
-- Function: admin.calculate_connecting_duration_minutes
-- Purpose: Calculate total trip duration including flight legs and layover time.
-- Responsibilities: Provide pure, reusable duration calculation respecting airport minimum transit time.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.calculate_connecting_duration_minutes(
  p_duration1        INTEGER,
  p_duration2        INTEGER DEFAULT NULL,
  p_layover_minutes  INTEGER DEFAULT 90
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF p_duration1 IS NULL OR p_duration1 <= 0 THEN
    p_duration1 := 0;
  END IF;

  IF p_duration2 IS NULL OR p_duration2 <= 0 THEN
    RETURN p_duration1;
  END IF;

  RETURN p_duration1 + p_duration2 + COALESCE(greatest(0, p_layover_minutes), 90);
END;
$$;

REVOKE ALL ON FUNCTION admin.calculate_connecting_duration_minutes(INTEGER, INTEGER, INTEGER)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.calculate_connecting_duration_minutes(INTEGER, INTEGER, INTEGER) TO service_role;
