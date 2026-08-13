-- On-demand staging publication must stay noindex and preserve a usable scope on an empty refresh.

BEGIN;

DO $$
DECLARE
  v_input       JSONB := '{
    "origin":"SGN",
    "destination":"SIN",
    "market":"vn",
    "currency":"USD",
    "locale":"en-GB"
  }'::JSONB;
  v_claim       JSONB;
  v_result      JSONB;
  v_price_count BIGINT;
BEGIN
  v_claim := public.rpc_claim_flight_route_cache_refresh(v_input);
  v_result := public.rpc_publish_flight_route_cache_scope(
    v_claim->>'leaseToken',
    'travelpayouts',
    'SGN',
    'SIN',
    'vn',
    'USD',
    'en-GB',
    jsonb_build_array(jsonb_build_object(
      'sourceId', 'staging-sgn-sin-2026-SQ-vn-en-GB',
      'originCode', 'SGN',
      'originAirportIata', 'SGN',
      'destinationCode', 'SIN',
      'destinationAirportIata', 'SIN',
      'airlineIata', 'SQ',
      'observationType', 'cached_fare',
      'tripType', 'one_way',
      'direct', TRUE,
      'transferCount', 0,
      'amount', 120,
      'currencyCode', 'USD',
      'marketCode', 'vn',
      'locale', 'en-GB',
      'departureDate', (CURRENT_DATE + 14)::TEXT,
      'returnDate', NULL,
      'durationMinutes', 125,
      'foundAt', now(),
      'providerExpiresAt', now() + INTERVAL '6 days',
      'validUntil', now() + INTERVAL '6 days',
      'affiliatePath', '/search/SGN/SIN'
    )),
    'staging'
  );

  IF v_result #>> '{data,status}' <> 'available' THEN
    RAISE EXCEPTION 'Expected an available staging cache, got %', v_result;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.publication_versions
    WHERE is_current AND source_type = 'staging'
  ) OR EXISTS (
    SELECT 1
    FROM public.pseo_pages
    WHERE is_indexable OR noindex_reason IS DISTINCT FROM 'staging_environment'
  ) THEN
    RAISE EXCEPTION 'Staging publication escaped the noindex boundary';
  END IF;

  SELECT count(*)
  INTO v_price_count
  FROM public.flight_route_prices AS price
  WHERE price.cache_key = (
    SELECT cache.cache_key
    FROM admin.flight_route_cache_states AS cache
    WHERE cache.origin_iata = 'SGN' AND cache.destination_iata = 'SIN'
  );

  UPDATE admin.flight_route_cache_states
  SET status = 'idle', next_refresh_at = now(), valid_until = NULL
  WHERE origin_iata = 'SGN' AND destination_iata = 'SIN';
  v_claim := public.rpc_claim_flight_route_cache_refresh(v_input);
  PERFORM public.rpc_publish_flight_route_cache_scope(
    v_claim->>'leaseToken', 'travelpayouts', 'SGN', 'SIN', 'vn', 'USD', 'en-GB',
    '[]'::JSONB, 'staging'
  );

  IF (
    SELECT count(*)
    FROM public.flight_route_prices AS price
    WHERE price.request_origin_iata = 'SGN' AND price.market_code = 'vn'
  ) <> v_price_count THEN
    RAISE EXCEPTION 'An empty refresh removed the last usable cache';
  END IF;
END;
$$;

ROLLBACK;
