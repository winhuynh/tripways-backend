\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(p_condition BOOLEAN, p_message TEXT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT COALESCE(p_condition, FALSE) THEN
    RAISE EXCEPTION 'ASSERTION FAILED: %', p_message;
  END IF;
END;
$$;

INSERT INTO admin.data_sources(
  id,code,provider_code,name,source_type,environment_scope,production_allowed,seo_allowed,
  derived_data_allowed,storage_allowed,retention_days,production_display_allowed,
  cache_allowed,max_cache_ttl_seconds,rights_effective_at,rights_expires_at
) VALUES(
  '10000000-0000-4000-8000-000000000099','price_estimate_test','fixture_adapter',
  'Price estimate contract test','schedule','production',TRUE,FALSE,TRUE,TRUE,30,TRUE,TRUE,3600,
  now()-interval '1 day',now()+interval '30 days'
);

SELECT pg_temp.test_assert(
  private.publish_price_estimate_batch(
    'price_estimate_test', 'price-estimate-fixture-0001', repeat('a', 64),
    'route-price-estimates.v1', now(),
    jsonb_build_array(jsonb_build_object(
      'sourceId', 'price-sgn-lhr',
      'originCitySourceId', 'city-sgn',
      'destinationCitySourceId', 'city-lon',
      'originAirportIata', 'SGN',
      'destinationAirportIata', 'LHR',
      'airlineIata', 'VN',
      'tripType', 'one_way', 'cabin', 'economy', 'stopBucket', 'direct',
      'baggageIncluded', NULL, 'priceMin', 450, 'priceMax', 720,
      'currencyCode', 'USD', 'estimateMethod', 'fixture_range',
      'sampleWindowStart', '2026-07-01', 'sampleWindowEnd', '2026-07-31',
      'sampleCount', 42, 'confidenceScore', 0.82,
      'lastVerifiedAt', now(), 'validUntil', now() + interval '7 days'
    ))
  ) #>> '{status}' = 'published',
  'licensed fresh estimates publish atomically'
);

SELECT pg_temp.test_assert(
  public.resolve_route_price_estimate('30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000004', 'economy', 'direct')
    #>> '{state}' = 'available',
  'eligible estimate resolves as available'
);

UPDATE public.route_price_estimates
SET last_verified_at = now() - interval '2 days', valid_until = now() - interval '1 day';
SELECT pg_temp.test_assert(
  public.resolve_route_price_estimate('30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000004', 'economy', 'direct')
    #>> '{reason}' = 'expired',
  'expired estimate is explicit and never becomes zero'
);

UPDATE admin.data_sources SET production_display_allowed = FALSE WHERE code = 'price_estimate_test';
SELECT pg_temp.test_assert(
  public.resolve_route_price_estimate('30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000004', 'economy', 'direct')
    #>> '{reason}' = 'unlicensed',
  'display rights revoke the estimate'
);

SELECT pg_temp.test_assert(
  public.resolve_route_price_estimate('30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000005', 'economy', 'direct')
    #>> '{reason}' = 'missing',
  'missing estimate returns a stable null state'
);

ROLLBACK;
