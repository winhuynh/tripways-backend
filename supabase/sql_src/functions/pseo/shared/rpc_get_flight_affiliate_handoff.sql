-- Resolve a current observation into an allowlisted Aviasales handoff URL.
-- The browser never supplies a destination host.
CREATE OR REPLACE FUNCTION public.rpc_get_flight_affiliate_handoff(p_observation_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path=''
AS $$
  SELECT CASE
    WHEN observation.id IS NULL OR source.id IS NULL THEN jsonb_build_object('data',NULL,'error',jsonb_build_object('code','ERR_HANDOFF_UNAVAILABLE'))
    ELSE jsonb_build_object(
      'data',jsonb_build_object(
        'url','https://www.aviasales.com' || observation.affiliate_path,
        'expires_at',observation.valid_until,
        'disclosure','Tripways may earn a commission if you book through this link. Final price and availability are confirmed by Aviasales.'
      ),
      'error',NULL
    )
  END
  FROM (SELECT p_observation_id AS requested_id) input
  LEFT JOIN public.flight_content_observations observation
    ON observation.id=input.requested_id
   AND observation.status='published'
   AND observation.valid_until>now()
   AND observation.affiliate_path IS NOT NULL
  LEFT JOIN admin.data_sources source
    ON source.id=observation.source_id
   AND source.provider_code='travelpayouts'
  ;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_flight_affiliate_handoff(UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.rpc_get_flight_affiliate_handoff(UUID) TO anon,authenticated,service_role;
