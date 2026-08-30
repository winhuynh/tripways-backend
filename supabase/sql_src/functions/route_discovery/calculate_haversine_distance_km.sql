-- ============================================================================
-- Function: admin.calculate_haversine_distance_km
-- Purpose: Calculate great-circle distance between two geographic coordinates in kilometers.
-- Responsibilities: Provide pure, immutable spherical distance computation for route metadata.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.calculate_haversine_distance_km(
  p_lat1 DOUBLE PRECISION,
  p_lon1 DOUBLE PRECISION,
  p_lat2 DOUBLE PRECISION,
  p_lon2 DOUBLE PRECISION
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_dlat DOUBLE PRECISION;
  v_dlon DOUBLE PRECISION;
  v_a    DOUBLE PRECISION;
  v_c    DOUBLE PRECISION;
  v_r    CONSTANT DOUBLE PRECISION := 6371.0;
BEGIN
  IF p_lat1 IS NULL OR p_lon1 IS NULL OR p_lat2 IS NULL OR p_lon2 IS NULL THEN
    RETURN 0;
  END IF;

  v_dlat := radians(p_lat2 - p_lat1);
  v_dlon := radians(p_lon2 - p_lon1);

  v_a := sin(v_dlat / 2.0) * sin(v_dlat / 2.0) +
         cos(radians(p_lat1)) * cos(radians(p_lat2)) *
         sin(v_dlon / 2.0) * sin(v_dlon / 2.0);

  v_c := 2.0 * atan2(sqrt(v_a), sqrt(greatest(0.0, 1.0 - v_a)));

  RETURN round(v_r * v_c)::INTEGER;
END;
$$;

REVOKE ALL ON FUNCTION admin.calculate_haversine_distance_km(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.calculate_haversine_distance_km(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO service_role;
