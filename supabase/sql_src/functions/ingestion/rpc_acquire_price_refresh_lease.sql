-- ============================================================================
-- Function: admin.rpc_acquire_price_refresh_lease
-- Purpose: Atomically acquire a price cache refresh lease or return fresh data.
-- Responsibilities: Prevent duplicate provider calls and manage refresh leases.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.rpc_acquire_price_refresh_lease(
  p_origin_iata TEXT,
  p_destination_iata TEXT DEFAULT NULL,
  p_currency_code TEXT DEFAULT 'USD',
  p_market_code TEXT DEFAULT 'us'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_origin_norm CHAR(3);
  v_dest_norm CHAR(3);
  v_curr_norm VARCHAR(3);
  v_market_norm VARCHAR(2);
  v_lease RECORD;
  v_fresh_count INTEGER;
  v_observations JSONB;
BEGIN
  v_origin_norm := upper(trim(p_origin_iata));
  v_dest_norm := CASE WHEN p_destination_iata IS NOT NULL AND length(trim(p_destination_iata)) > 0 THEN upper(trim(p_destination_iata)) ELSE NULL END;
  v_curr_norm := upper(trim(coalesce(p_currency_code, 'USD')));
  v_market_norm := lower(trim(coalesce(p_market_code, 'us')));

  IF v_origin_norm !~ '^[A-Z]{3}$' OR (v_dest_norm IS NOT NULL AND v_dest_norm !~ '^[A-Z]{3}$') THEN
    RETURN jsonb_build_object('status', 'failed', 'error', 'ERR_INVALID_IATA');
  END IF;

  -- 1. Check existing fresh published prices
  SELECT count(*), jsonb_agg(
    jsonb_build_object(
      'observation_ref', p.public_reference,
      'observed_amount', p.observed_amount,
      'currency_code', p.currency_code,
      'departure_date', p.departure_date,
      'direct', p.direct,
      'transfer_count', p.transfer_count,
      'duration_minutes', p.duration_minutes,
      'observed_at', p.observed_at,
      'valid_until', p.valid_until
    ) ORDER BY p.observed_amount ASC NULLS LAST
  )
  INTO v_fresh_count, v_observations
  FROM public.flight_route_prices AS p
  JOIN public.cities AS oc ON oc.id = p.origin_city_id
  JOIN public.airports AS oa ON oa.city_id = oc.id AND oa.iata = v_origin_norm
  LEFT JOIN public.cities AS dc ON dc.id = p.destination_city_id
  LEFT JOIN public.airports AS da ON da.city_id = dc.id AND da.iata = v_dest_norm
  WHERE p.status = 'published'
    AND p.valid_until > now()
    AND p.currency_code = v_curr_norm
    AND p.market_code = v_market_norm
    AND (v_dest_norm IS NULL OR da.id IS NOT NULL);

  IF v_fresh_count > 0 THEN
    RETURN jsonb_build_object(
      'status', 'fresh',
      'origin', v_origin_norm,
      'destination', v_dest_norm,
      'count', v_fresh_count,
      'observations', v_observations
    );
  END IF;

  -- 2. Check or upsert lease state
  INSERT INTO admin.route_price_cache_leases (
    origin_iata, destination_iata, market_code, currency_code, status, lease_expires_at, last_attempted_at, next_allowed_refresh_at
  ) VALUES (
    v_origin_norm, v_dest_norm, v_market_norm, v_curr_norm, 'refreshing', now() + interval '30 seconds', now(), now() + interval '30 seconds'
  )
  ON CONFLICT (origin_iata, destination_iata, market_code, currency_code)
  DO UPDATE SET
    last_attempted_at = now(),
    status = CASE
      WHEN route_price_cache_leases.lease_expires_at < now() THEN 'refreshing'
      ELSE route_price_cache_leases.status
    END,
    lease_expires_at = CASE
      WHEN route_price_cache_leases.lease_expires_at < now() THEN now() + interval '30 seconds'
      ELSE route_price_cache_leases.lease_expires_at
    END
  RETURNING * INTO v_lease;

  IF v_lease.status = 'refreshing' AND v_lease.lease_expires_at >= now() THEN
    RETURN jsonb_build_object(
      'status', 'lease_acquired',
      'origin', v_origin_norm,
      'destination', v_dest_norm,
      'lease_id', v_lease.id
    );
  ELSIF v_lease.next_allowed_refresh_at > now() AND v_lease.status IN ('empty', 'failed') THEN
    RETURN jsonb_build_object(
      'status', 'cooldown',
      'origin', v_origin_norm,
      'destination', v_dest_norm,
      'next_allowed_refresh_at', v_lease.next_allowed_refresh_at
    );
  ELSE
    RETURN jsonb_build_object(
      'status', 'refreshing',
      'origin', v_origin_norm,
      'destination', v_dest_norm
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION admin.rpc_acquire_price_refresh_lease(TEXT, TEXT, TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.rpc_acquire_price_refresh_lease(TEXT, TEXT, TEXT, TEXT) TO service_role;
