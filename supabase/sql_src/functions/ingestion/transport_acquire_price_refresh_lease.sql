-- ============================================================================
-- Function: public.rpc_acquire_price_refresh_lease
-- Purpose: PostgREST transport wrapper for price cache lease acquisition.
-- Responsibilities: Forward request to internal admin function, enforce service_role only.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_acquire_price_refresh_lease(
  p_origin_iata TEXT,
  p_destination_iata TEXT DEFAULT NULL,
  p_currency_code TEXT DEFAULT 'USD',
  p_market_code TEXT DEFAULT 'us'
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.rpc_acquire_price_refresh_lease(p_origin_iata, p_destination_iata, p_currency_code, p_market_code);
$$;

REVOKE ALL ON FUNCTION public.rpc_acquire_price_refresh_lease(TEXT, TEXT, TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_acquire_price_refresh_lease(TEXT, TEXT, TEXT, TEXT) TO service_role;
