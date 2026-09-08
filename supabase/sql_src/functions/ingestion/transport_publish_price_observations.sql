-- ============================================================================
-- Function: public.rpc_publish_price_observations
-- Purpose: PostgREST transport wrapper for price observation publishing.
-- Responsibilities: Forward request to internal admin function, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_publish_price_observations(
  p_origin_iata TEXT,
  p_destination_iata TEXT,
  p_currency_code TEXT,
  p_market_code TEXT,
  p_observations JSONB,
  p_lease_token UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.rpc_publish_price_observations(p_origin_iata, p_destination_iata, p_currency_code, p_market_code, p_observations, p_lease_token);
$$;

REVOKE ALL ON FUNCTION public.rpc_publish_price_observations(TEXT, TEXT, TEXT, TEXT, JSONB, UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_publish_price_observations(TEXT, TEXT, TEXT, TEXT, JSONB, UUID) TO service_role;
