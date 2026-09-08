-- ============================================================================
-- Function: admin.rpc_get_day6_active_routes_to_refresh
-- Purpose: Query routes with active demand in last 30 days that are reaching Day 6 of 7-day TTL.
-- Responsibilities: Scan route_price_cache_leases for active routes needing proactive refresh.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.rpc_get_day6_active_routes_to_refresh(
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
      'origin_iata', l.origin_iata,
      'destination_iata', l.destination_iata,
      'currency_code', l.currency_code,
      'market_code', l.market_code
    )
  ), '[]'::JSONB)
  INTO v_results
  FROM (
    SELECT
      l.origin_iata,
      l.destination_iata,
      l.currency_code,
      l.market_code
    FROM admin.route_price_cache_leases l
    WHERE l.last_attempted_at >= now() - INTERVAL '30 days'
      AND l.status IN ('fresh', 'empty', 'failed')
      AND (
        -- Day 6 check: last successful update was 6+ days ago, or prices expire within 24 hours
        l.last_succeeded_at <= now() - INTERVAL '6 days'
        OR EXISTS (
          SELECT 1
          FROM public.flight_route_prices p
          JOIN public.airports oa ON oa.id = p.origin_airport_id AND oa.iata = l.origin_iata
          LEFT JOIN public.airports da ON da.id = p.destination_airport_id AND da.iata = l.destination_iata
          WHERE p.status = 'published'
            AND p.valid_until <= now() + INTERVAL '24 hours'
            AND p.currency_code = l.currency_code
            AND p.market_code = l.market_code
            AND (l.destination_iata IS NULL OR da.id IS NOT NULL)
        )
      )
    ORDER BY l.last_attempted_at DESC
    LIMIT v_limit
  ) l;

  RETURN v_results;
END;
$$;

REVOKE ALL ON FUNCTION admin.rpc_get_day6_active_routes_to_refresh(INTEGER) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.rpc_get_day6_active_routes_to_refresh(INTEGER) TO service_role;
