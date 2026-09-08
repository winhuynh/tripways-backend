-- ============================================================================
-- Function: admin.rpc_get_top_routes_to_warm
-- Purpose: Query top active flight routes/hubs to pre-warm in Travelpayouts price cache.
-- Responsibilities: Select prominent hub routes and high-frequency city connections.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.rpc_get_top_routes_to_warm(
  p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit INTEGER;
  v_results JSONB;
BEGIN
  v_limit := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'origin_iata', r.origin_iata,
      'destination_iata', r.destination_iata
    )
  ), '[]'::JSONB)
  INTO v_results
  FROM (
    SELECT dfr.origin_iata, dfr.destination_iata
    FROM public.direct_flight_routes dfr
    JOIN public.airports oa ON oa.iata = dfr.origin_iata AND oa.status = 'active'
    JOIN public.airports da ON da.iata = dfr.destination_iata AND da.status = 'active'
    WHERE dfr.is_active = TRUE
    GROUP BY dfr.origin_iata, dfr.destination_iata
    ORDER BY
      (max(oa.is_hub::INT) + max(da.is_hub::INT)) DESC,
      count(*) DESC,
      dfr.origin_iata, dfr.destination_iata
    LIMIT v_limit
  ) r;

  RETURN v_results;
END;
$$;

REVOKE ALL ON FUNCTION admin.rpc_get_top_routes_to_warm(INTEGER) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.rpc_get_top_routes_to_warm(INTEGER) TO service_role;
