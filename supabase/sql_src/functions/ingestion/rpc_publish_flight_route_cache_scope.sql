-- ============================================================================
-- Function: public.rpc_publish_flight_route_cache_scope
-- Purpose: Expose origin-scoped publication to the trusted cache-aside Edge Function.
-- Responsibilities: Forward one validated service-role request to the admin publisher.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_publish_flight_route_cache_scope(
  p_lease_token      TEXT,
  p_source_code      TEXT,
  p_origin_iata      TEXT,
  p_destination_iata TEXT,
  p_market_code      TEXT,
  p_currency_code    TEXT,
  p_locale           TEXT,
  p_observations     JSONB,
  p_publication_source_type TEXT
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.publish_flight_route_cache_scope(
    p_lease_token,
    p_source_code,
    p_origin_iata,
    p_destination_iata,
    p_market_code,
    p_currency_code,
    p_locale,
    p_observations,
    p_publication_source_type
  );
$$;

REVOKE ALL ON FUNCTION public.rpc_publish_flight_route_cache_scope(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_publish_flight_route_cache_scope(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
)
TO service_role;
