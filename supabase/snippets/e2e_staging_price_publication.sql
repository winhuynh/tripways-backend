-- Staging price publication must stay noindex and preserve the last usable cache.

BEGIN;

DO $$
DECLARE
  v_result       JSONB;
  v_empty_result JSONB;
  v_price_count  BIGINT;
BEGIN
  v_result := admin.publish_price_estimate_batch(
    'travelpayouts',
    'staging-price-e2e-valid',
    repeat('c', 64),
    'flight-content-observations.v1',
    now(),
    jsonb_build_array(jsonb_build_object(
      'sourceId', 'staging-sgn-sin',
      'originCode', 'SGN',
      'originAirportIata', 'SGN',
      'destinationCode', 'SIN',
      'destinationAirportIata', 'SIN',
      'airlineIata', 'VN',
      'observationType', 'cached_fare',
      'tripType', 'one_way',
      'direct', TRUE,
      'transferCount', 0,
      'amount', 120,
      'currencyCode', 'USD',
      'marketCode', 'vn',
      'locale', 'en-US',
      'departureDate', (CURRENT_DATE + 14)::TEXT,
      'returnDate', NULL,
      'durationMinutes', NULL,
      'foundAt', now(),
      'providerExpiresAt', now() + interval '6 days',
      'validUntil', now() + interval '6 days',
      'affiliatePath', '/search/SGN/SIN'
    )),
    'staging'
  );

  IF v_result->>'status' <> 'published' OR NULLIF(v_result->>'dataVersion', '') IS NULL THEN
    RAISE EXCEPTION 'Expected an atomic staging publication, got %', v_result;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.publication_versions
    WHERE is_current
      AND source_type = 'staging'
  ) OR EXISTS (
    SELECT 1
    FROM public.pseo_pages
    WHERE is_indexable
      OR noindex_reason IS DISTINCT FROM 'staging_environment'
  ) THEN
    RAISE EXCEPTION 'Staging publication escaped the noindex boundary';
  END IF;

  SELECT count(*)
  INTO v_price_count
  FROM public.flight_route_prices AS price
  JOIN admin.data_sources AS source
    ON source.id = price.source_id
  WHERE source.code = 'travelpayouts';

  v_empty_result := admin.publish_price_estimate_batch(
    'travelpayouts',
    'staging-price-e2e-empty',
    repeat('d', 64),
    'flight-content-observations.v1',
    now(),
    '[]'::JSONB,
    'staging'
  );

  IF v_empty_result->>'errorCode' <> 'ERR_INGESTION_NO_USABLE_PRICES'
    OR (
      SELECT count(*)
      FROM public.flight_route_prices AS price
      JOIN admin.data_sources AS source
        ON source.id = price.source_id
      WHERE source.code = 'travelpayouts'
    ) <> v_price_count
  THEN
    RAISE EXCEPTION 'An unusable refresh did not preserve the current cache';
  END IF;
END;
$$;

ROLLBACK;
