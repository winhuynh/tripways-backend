import assert from 'node:assert/strict';
import { parseCanonicalPriceEstimateBatch } from '../provider-contract.ts';

const validPayload = {
  schemaVersion: 'route-price-estimates.v1',
  sourceTime: '2026-08-03T00:00:00Z',
  estimates: [{
    sourceId: 'sgn-lhr-economy',
    originCitySourceId: 'city-sgn',
    destinationCitySourceId: 'city-lon',
    originAirportIata: 'SGN',
    destinationAirportIata: 'LHR',
    airlineIata: 'VN',
    tripType: 'one_way',
    cabin: 'economy',
    stopBucket: 'direct',
    baggageIncluded: null,
    priceMin: 450,
    priceMax: 720,
    currencyCode: 'USD',
    estimateMethod: 'provider_observed_range',
    sampleWindowStart: '2026-07-01',
    sampleWindowEnd: '2026-07-31',
    sampleCount: 42,
    confidenceScore: 0.82,
    lastVerifiedAt: '2026-08-03T00:00:00Z',
    validUntil: '2026-08-10T00:00:00Z',
  }],
};

Deno.test('price estimate parser accepts normalized bounded estimates', () => {
  const result = parseCanonicalPriceEstimateBatch(validPayload);
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.batch.estimates[0]?.currencyCode, 'USD');
});

Deno.test('price estimate parser rejects inverted bounds', () => {
  const payload = structuredClone(validPayload);
  payload.estimates[0]!.priceMin = 800;
  const result = parseCanonicalPriceEstimateBatch(payload);
  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_INVALID_PRICE_BOUNDS');
});

Deno.test('price estimate parser rejects invalid currency and expiry', () => {
  const payload = structuredClone(validPayload);
  payload.estimates[0]!.currencyCode = 'usd';
  payload.estimates[0]!.validUntil = '2026-08-02T00:00:00Z';
  const result = parseCanonicalPriceEstimateBatch(payload);
  assert.deepEqual(
    result.ok ? [] : result.issues.map((issue) => issue.code),
    ['ERR_INVALID_CURRENCY', 'ERR_INVALID_VALIDITY_WINDOW'],
  );
});

Deno.test('price estimate parser rejects unsupported schema versions', () => {
  const result = parseCanonicalPriceEstimateBatch({ ...validPayload, schemaVersion: 'v2' });
  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_UNSUPPORTED_SCHEMA_VERSION');
});
