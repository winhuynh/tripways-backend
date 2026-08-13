-- ============================================================================
-- Function: public.rpc_get_flight_affiliate_handoff
-- Purpose: Resolve an opaque public observation reference to an allowlisted partner URL.
-- Responsibilities: Enforce freshness, provider allowlisting, and server-owned destinations.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_flight_affiliate_handoff(p_observation_ref TEXT)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN observation.public_reference IS NULL THEN
      jsonb_build_object(
        'data', NULL,
        'error', jsonb_build_object('code', 'ERR_HANDOFF_UNAVAILABLE')
      )
    ELSE
      jsonb_build_object(
        'data', jsonb_build_object(
          'url', 'https://www.aviasales.com' || observation.affiliate_path,
          'expires_at', observation.valid_until,
          'disclosure', 'Tripways may earn a commission if you book through this link. Final price and availability are confirmed by Aviasales.'
        ),
        'error', NULL
      )
  END
  FROM (SELECT p_observation_ref AS requested_reference) AS input
  LEFT JOIN public.flight_route_prices AS observation
    ON observation.public_reference = input.requested_reference
   AND observation.status = 'published'
   AND observation.valid_until > now()
   AND observation.affiliate_path IS NOT NULL
   AND observation.provider_code = 'travelpayouts';
$$;

REVOKE ALL ON FUNCTION public.rpc_get_flight_affiliate_handoff(TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_flight_affiliate_handoff(TEXT) TO service_role;
