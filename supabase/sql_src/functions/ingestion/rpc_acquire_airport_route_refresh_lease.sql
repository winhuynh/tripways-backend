-- ============================================================================
-- Function: admin.rpc_acquire_airport_route_refresh_lease
-- Purpose: Atomically acquire an on-demand route cache refresh lease or return fresh data.
-- Responsibilities:
--   - Validate origin IATA against active registered airports.
--   - Return 'fresh' if routes synced within 7 days exist.
--   - Coordinate leases to prevent thundering herd calls to AeroDataBox.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.rpc_acquire_airport_route_refresh_lease(
  p_origin_iata TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_origin_norm CHAR(3);
  v_airport_id UUID;
  v_fresh_count INTEGER := 0;
  v_lease RECORD;
  v_new_token UUID;
BEGIN
  v_origin_norm := pg_catalog.upper(pg_catalog.btrim(COALESCE(p_origin_iata, '')));

  IF v_origin_norm !~ '^[A-Z]{3}$' THEN
    RETURN pg_catalog.jsonb_build_object('status', 'failed', 'error', 'ERR_INVALID_IATA');
  END IF;

  -- 1. Ensure airport exists and is active in master directory
  SELECT id INTO v_airport_id
  FROM public.airports
  WHERE iata = v_origin_norm
    AND status = 'active'
  LIMIT 1;

  IF v_airport_id IS NULL THEN
    RETURN pg_catalog.jsonb_build_object('status', 'failed', 'error', 'ERR_UNKNOWN_AIRPORT');
  END IF;

  -- 2. Check for fresh direct routes (TTL 7 days)
  SELECT count(*) INTO v_fresh_count
  FROM public.direct_flight_routes
  WHERE origin_iata = v_origin_norm
    AND is_active = TRUE
    AND last_synced_at >= (pg_catalog.now() - INTERVAL '7 days');

  IF v_fresh_count > 0 THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', 'fresh',
      'origin', v_origin_norm,
      'count', v_fresh_count
    );
  END IF;

  -- 3. Atomic lease acquisition with unique token
  v_new_token := gen_random_uuid();

  INSERT INTO admin.airport_route_cache_leases (
    origin_iata, status, lease_token, lease_expires_at, last_attempted_at, next_allowed_refresh_at
  ) VALUES (
    v_origin_norm, 'refreshing', v_new_token, pg_catalog.now() + INTERVAL '30 seconds', pg_catalog.now(), pg_catalog.now() + INTERVAL '30 seconds'
  )
  ON CONFLICT (origin_iata)
  DO UPDATE SET
    last_attempted_at = pg_catalog.now(),
    status = CASE
      WHEN airport_route_cache_leases.status = 'refreshing' AND airport_route_cache_leases.lease_expires_at >= pg_catalog.now()
        THEN airport_route_cache_leases.status
      WHEN airport_route_cache_leases.status IN ('empty', 'failed') AND airport_route_cache_leases.next_allowed_refresh_at > pg_catalog.now()
        THEN airport_route_cache_leases.status
      ELSE 'refreshing'
    END,
    lease_token = CASE
      WHEN airport_route_cache_leases.status = 'refreshing' AND airport_route_cache_leases.lease_expires_at >= pg_catalog.now()
        THEN airport_route_cache_leases.lease_token
      WHEN airport_route_cache_leases.status IN ('empty', 'failed') AND airport_route_cache_leases.next_allowed_refresh_at > pg_catalog.now()
        THEN airport_route_cache_leases.lease_token
      ELSE v_new_token
    END,
    lease_expires_at = CASE
      WHEN airport_route_cache_leases.status = 'refreshing' AND airport_route_cache_leases.lease_expires_at >= pg_catalog.now()
        THEN airport_route_cache_leases.lease_expires_at
      WHEN airport_route_cache_leases.status IN ('empty', 'failed') AND airport_route_cache_leases.next_allowed_refresh_at > pg_catalog.now()
        THEN airport_route_cache_leases.lease_expires_at
      ELSE pg_catalog.now() + INTERVAL '30 seconds'
    END
  RETURNING * INTO v_lease;

  IF v_lease.lease_token = v_new_token THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', 'lease_acquired',
      'origin', v_origin_norm,
      'lease_id', v_lease.id,
      'lease_token', v_new_token
    );
  ELSIF v_lease.next_allowed_refresh_at > pg_catalog.now() AND v_lease.status IN ('empty', 'failed') THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', 'cooldown',
      'origin', v_origin_norm,
      'next_allowed_refresh_at', v_lease.next_allowed_refresh_at
    );
  ELSE
    RETURN pg_catalog.jsonb_build_object(
      'status', 'refreshing',
      'origin', v_origin_norm,
      'retry_after_seconds', GREATEST(1, EXTRACT(EPOCH FROM (coalesce(v_lease.lease_expires_at, pg_catalog.now() + INTERVAL '30 seconds') - pg_catalog.now()))::INTEGER)
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION admin.rpc_acquire_airport_route_refresh_lease(TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.rpc_acquire_airport_route_refresh_lease(TEXT) TO service_role;
