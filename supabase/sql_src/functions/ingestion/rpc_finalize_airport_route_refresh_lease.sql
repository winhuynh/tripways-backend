-- ============================================================================
-- Function: admin.rpc_finalize_airport_route_refresh_lease
-- Purpose: Finalize the lease state after an on-demand route ingestion attempt.
-- Responsibilities: Update status to fresh/empty/failed and set cooldown.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.rpc_finalize_airport_route_refresh_lease(
  p_origin_iata TEXT,
  p_status TEXT,
  p_failure_code TEXT DEFAULT NULL,
  p_lease_token UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_origin_norm CHAR(3);
  v_status_norm VARCHAR(20);
  v_failure_code VARCHAR(50);
  v_row_count INTEGER := 0;
  v_lease_token UUID;
  v_lease_expires_at TIMESTAMPTZ;
  v_lease_status VARCHAR(20);
BEGIN
  v_origin_norm := pg_catalog.upper(pg_catalog.btrim(COALESCE(p_origin_iata, '')));
  v_status_norm := pg_catalog.lower(pg_catalog.btrim(COALESCE(p_status, '')));
  v_failure_code := CASE
    WHEN p_failure_code IS NOT NULL THEN pg_catalog.substr(pg_catalog.btrim(p_failure_code), 1, 50)
    ELSE NULL
  END;

  IF v_origin_norm !~ '^[A-Z]{3}$' THEN
    RETURN pg_catalog.jsonb_build_object('status', 'failed', 'error', 'ERR_INVALID_IATA');
  END IF;

  IF v_status_norm NOT IN ('fresh', 'empty', 'failed') THEN
    RETURN pg_catalog.jsonb_build_object('status', 'failed', 'error', 'ERR_INVALID_STATUS');
  END IF;

  IF p_lease_token IS NULL THEN
    RETURN pg_catalog.jsonb_build_object('status', 'failed', 'error', 'ERR_LEASE_TOKEN_REQUIRED');
  END IF;

  -- Lock lease row and verify token fencing BEFORE finalizing (Finding R3)
  SELECT lease_token, lease_expires_at, status
  INTO v_lease_token, v_lease_expires_at, v_lease_status
  FROM admin.airport_route_cache_leases
  WHERE origin_iata = v_origin_norm
  FOR UPDATE;

  IF v_lease_token IS NULL
     OR v_lease_token <> p_lease_token
     OR v_lease_expires_at < pg_catalog.now()
     OR v_lease_status <> 'refreshing' THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', 'failed',
      'error', 'ERR_LEASE_LOST',
      'origin', v_origin_norm
    );
  END IF;

  UPDATE admin.airport_route_cache_leases
  SET
    status = v_status_norm,
    lease_token = NULL,
    lease_expires_at = NULL,
    last_succeeded_at = CASE WHEN v_status_norm = 'fresh' THEN pg_catalog.now() ELSE last_succeeded_at END,
    next_allowed_refresh_at = CASE
      WHEN v_status_norm = 'fresh' THEN pg_catalog.now() + INTERVAL '7 days'
      ELSE pg_catalog.now() + INTERVAL '24 hours'
    END,
    failure_code = v_failure_code,
    updated_at = pg_catalog.now()
  WHERE origin_iata = v_origin_norm
    AND lease_token = p_lease_token;

  GET DIAGNOSTICS v_row_count = ROW_COUNT;

  IF v_row_count = 0 THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', 'failed',
      'error', 'ERR_LEASE_LOST',
      'origin', v_origin_norm
    );
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'status', 'success',
    'origin', v_origin_norm,
    'lease_status', v_status_norm
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.rpc_finalize_airport_route_refresh_lease(TEXT, TEXT, TEXT, UUID) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.rpc_finalize_airport_route_refresh_lease(TEXT, TEXT, TEXT, UUID) TO service_role;
