-- ============================================================================
-- Function: admin.calculate_route_schedule_intersection
-- Purpose: Compute the intersection of operating days-of-week for connecting flights.
-- Responsibilities: Provide pure, reusable schedule compatibility calculation.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.calculate_route_schedule_intersection(
  p_days1 INTEGER[],
  p_days2 INTEGER[] DEFAULT NULL
)
RETURNS INTEGER[]
LANGUAGE plpgsql
IMMUTABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_intersection INTEGER[];
BEGIN
  IF p_days1 IS NULL OR cardinality(p_days1) = 0 THEN
    p_days1 := '{1,2,3,4,5,6,7}'::INTEGER[];
  END IF;

  IF p_days2 IS NULL OR cardinality(p_days2) = 0 THEN
    RETURN p_days1;
  END IF;

  SELECT ARRAY(
    SELECT unnest(p_days1)
    INTERSECT
    SELECT unnest(p_days2)
    ORDER BY 1
  ) INTO v_intersection;

  IF cardinality(v_intersection) = 0 THEN
    RETURN p_days1;
  END IF;

  RETURN v_intersection;
END;
$$;

REVOKE ALL ON FUNCTION admin.calculate_route_schedule_intersection(INTEGER[], INTEGER[])
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.calculate_route_schedule_intersection(INTEGER[], INTEGER[]) TO service_role;
