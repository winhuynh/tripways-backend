-- ============================================================================
-- Function: public.rpc_claim_flight_route_cache_refresh
-- Purpose: Atomically claim one provider refresh lease for a canonical cache scope.
-- Responsibilities: Validate identity, deduplicate misses, and enforce cooldown.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_claim_flight_route_cache_refresh(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_origin_iata      TEXT := upper(p_input->>'origin');
  v_destination_iata TEXT := NULLIF(upper(p_input->>'destination'), '');
  v_market_code      TEXT := lower(p_input->>'market');
  v_currency_code    TEXT := upper(p_input->>'currency');
  v_locale           TEXT := p_input->>'locale';
  v_cache_key         TEXT;
  v_cache             admin.flight_route_cache_states%ROWTYPE;
  v_lease_token       TEXT;
BEGIN
  v_cache_key := 'frc_' || md5(
    v_origin_iata || '|' || COALESCE(v_destination_iata, '*') || '|' ||
    v_market_code || '|' || v_currency_code || '|' || v_locale
  );

  IF v_origin_iata !~ '^[A-Z0-9]{3}$'
    OR (v_destination_iata IS NOT NULL AND v_destination_iata !~ '^[A-Z0-9]{3}$')
    OR v_destination_iata = v_origin_iata
    OR v_market_code !~ '^[a-z]{2}$'
    OR v_currency_code !~ '^[A-Z]{3}$'
    OR v_locale !~ '^[a-z]{2}(?:-[A-Z]{2})?$'
    OR NOT EXISTS (
      SELECT 1 FROM public.airports AS airport WHERE airport.iata = v_origin_iata
      UNION ALL
      SELECT 1 FROM public.cities AS city WHERE city.iata_code = v_origin_iata
    )
    OR (
      v_destination_iata IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.airports AS airport WHERE airport.iata = v_destination_iata
        UNION ALL
        SELECT 1 FROM public.cities AS city WHERE city.iata_code = v_destination_iata
      )
    )
  THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST';
  END IF;

  INSERT INTO admin.flight_route_cache_states (
    cache_key,
    origin_iata,
    destination_iata,
    market_code,
    currency_code,
    locale
  )
  VALUES (
    v_cache_key,
    v_origin_iata,
    v_destination_iata,
    v_market_code,
    v_currency_code,
    v_locale
  )
  ON CONFLICT (cache_key)
  DO UPDATE SET last_requested_at = now(), updated_at = now();

  SELECT cache.*
  INTO v_cache
  FROM admin.flight_route_cache_states AS cache
  WHERE cache.cache_key = v_cache_key
  FOR UPDATE;

  IF v_cache.status = 'refreshing' AND v_cache.lease_expires_at > now() THEN
    RETURN jsonb_build_object('action', 'wait');
  END IF;

  IF v_cache.status IN ('empty', 'failed') AND v_cache.next_refresh_at > now() THEN
    RETURN jsonb_build_object('action', 'cooldown');
  END IF;

  IF v_cache.status = 'fresh' AND v_cache.valid_until > now() THEN
    RETURN jsonb_build_object('action', 'wait');
  END IF;

  -- STEP 03: Serialize and enforce one hard provider-call budget across all public callers.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('tripways:flight-route-cache-daily-budget', 0)
  );
  IF (
    SELECT count(*)
    FROM admin.flight_route_cache_states AS cache
    WHERE cache.last_attempted_at >= date_trunc('day', now())
  ) >= 500 THEN
    RETURN jsonb_build_object('action', 'cooldown');
  END IF;

  v_lease_token := 'lease_' || replace(gen_random_uuid()::TEXT, '-', '');
  UPDATE admin.flight_route_cache_states AS cache
  SET
    status = 'refreshing',
    lease_token = v_lease_token,
    lease_expires_at = now() + INTERVAL '2 minutes',
    last_attempted_at = now(),
    updated_at = now()
  WHERE cache.cache_key = v_cache_key;

  RETURN jsonb_build_object('action', 'refresh', 'leaseToken', v_lease_token);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_claim_flight_route_cache_refresh(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_claim_flight_route_cache_refresh(JSONB) TO service_role;
