\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(
  p_condition BOOLEAN,
  p_message TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT COALESCE(p_condition, FALSE) THEN
    RAISE EXCEPTION 'ASSERTION FAILED: %', p_message;
  END IF;
END;
$$;

DO $$
DECLARE
  v_input JSONB := '{
    "origin":"SGN",
    "destination":"LON",
    "market":"us",
    "currency":"USD",
    "locale":"en-GB"
  }'::JSONB;
  v_claim JSONB;
  v_response JSONB;
  v_sgn_cache_key TEXT;
BEGIN
  v_claim := public.rpc_claim_flight_route_cache_refresh(v_input);
  PERFORM pg_temp.test_assert(v_claim->>'action' = 'refresh', 'cache miss receives a lease');

  v_response := public.rpc_publish_flight_route_cache_scope(
    v_claim->>'leaseToken',
    'travelpayouts',
    'SGN',
    'LON',
    'us',
    'USD',
    'en-GB',
    jsonb_build_array(jsonb_build_object(
      'sourceId', 'SGN-LON-2026-09-12-VN-us-en-GB',
      'observationType', 'cached_fare',
      'originCode', 'SGN',
      'destinationCode', 'LON',
      'originAirportIata', 'SGN',
      'destinationAirportIata', 'LHR',
      'airlineIata', 'VN',
      'tripType', 'one_way',
      'direct', TRUE,
      'transferCount', 0,
      'amount', 450,
      'currencyCode', 'USD',
      'marketCode', 'us',
      'locale', 'en-GB',
      'departureDate', (CURRENT_DATE + 30)::TEXT,
      'returnDate', NULL,
      'durationMinutes', 780,
      'foundAt', now(),
      'providerExpiresAt', now() + INTERVAL '6 days',
      'validUntil', now() + INTERVAL '6 days',
      'affiliatePath', '/search/SGN-LON'
    )),
    'staging'
  );

  PERFORM pg_temp.test_assert(
    v_response #>> '{data,status}' = 'available',
    'successful fill returns an available cache'
  );
  PERFORM pg_temp.test_assert(
    jsonb_array_length(v_response #> '{data,routes}') = 1,
    'successful fill returns one normalized route'
  );

  SELECT cache.cache_key
  INTO v_sgn_cache_key
  FROM admin.flight_route_cache_states AS cache
  WHERE cache.origin_iata = 'SGN' AND cache.destination_iata = 'LON';

  v_claim := public.rpc_claim_flight_route_cache_refresh('{
    "origin":"SIN",
    "destination":"LON",
    "market":"us",
    "currency":"USD",
    "locale":"en-GB"
  }'::JSONB);

  PERFORM public.rpc_publish_flight_route_cache_scope(
    v_claim->>'leaseToken',
    'travelpayouts',
    'SIN',
    'LON',
    'us',
    'USD',
    'en-GB',
    '[]'::JSONB,
    'staging'
  );

  PERFORM pg_temp.test_assert(
    EXISTS (
      SELECT 1
      FROM public.flight_route_prices AS price
      WHERE price.cache_key = v_sgn_cache_key
    ),
    'publishing another origin never deletes the SGN cache'
  );
  PERFORM pg_temp.test_assert(
    public.rpc_claim_flight_route_cache_refresh('{
      "origin":"SIN",
      "destination":"LON",
      "market":"us",
      "currency":"USD",
      "locale":"en-GB"
    }'::JSONB)->>'action' = 'cooldown',
    'an empty provider result starts a bounded cooldown'
  );
END;
$$;

SELECT pg_temp.test_assert(
  NOT has_function_privilege('anon', 'public.rpc_get_flight_route_cache(jsonb)', 'EXECUTE'),
  'anonymous clients cannot bypass the Edge cache boundary'
);

ROLLBACK;
