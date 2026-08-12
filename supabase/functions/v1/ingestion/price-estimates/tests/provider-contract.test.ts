import assert from 'node:assert/strict';
import { parseFlightContentObservationBatch } from '../provider-contract.ts';

const validPayload = {
  schemaVersion: 'flight-content-observations.v1',
  sourceTime: '2026-08-12T00:00:00Z',
  observations: [{
    sourceId: 'sgn-lhr-2026-09-12',
    observationType: 'cached_fare',
    originCode: 'SGN',
    destinationCode: 'LON',
    originAirportIata: 'SGN',
    destinationAirportIata: 'LHR',
    airlineIata: 'VN',
    tripType: 'one_way',
    direct: true,
    transferCount: 0,
    amount: 450,
    currencyCode: 'USD',
    marketCode: 'vn',
    locale: 'en-GB',
    departureDate: '2026-09-12',
    returnDate: null,
    durationMinutes: 780,
    foundAt: '2026-08-12T00:00:00Z',
    providerExpiresAt: '2026-08-14T00:00:00Z',
    validUntil: '2026-08-13T00:00:00Z',
    affiliatePath: '/search/SGN1209LON1',
  }],
};

Deno.test('content parser accepts one bounded cached-fare observation', () => {
  const result = parseFlightContentObservationBatch(validPayload);
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.batch.observations[0]?.amount, 450);
  assert.equal(result.batch.observations[0]?.direct, true);
});

Deno.test('content parser keeps a missing fare as null', () => {
  const payload = structuredClone(validPayload);
  payload.observations[0]!.amount = null as unknown as number;
  const result = parseFlightContentObservationBatch(payload);
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.batch.observations[0]?.amount, null);
});

Deno.test('content parser rejects validity beyond seven days', () => {
  const payload = structuredClone(validPayload);
  payload.observations[0]!.providerExpiresAt = null as unknown as string;
  payload.observations[0]!.validUntil = '2026-08-19T00:00:01Z';
  const result = parseFlightContentObservationBatch(payload);
  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_INVALID_VALIDITY_WINDOW');
});

Deno.test('content parser rejects invalid currency and browser-controlled URLs', () => {
  const payload = structuredClone(validPayload);
  payload.observations[0]!.currencyCode = 'usd';
  payload.observations[0]!.affiliatePath = 'https://evil.example/redirect';
  const result = parseFlightContentObservationBatch(payload);
  assert.deepEqual(
    result.ok ? [] : result.issues.map((issue) => issue.code),
    ['ERR_INVALID_CURRENCY', 'ERR_INVALID_AFFILIATE_REFERENCE'],
  );
});
