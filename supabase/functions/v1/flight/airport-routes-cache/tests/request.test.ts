import assert from 'node:assert/strict';
import { parseAirportRoutesCacheRequest } from '../request.ts';

Deno.test('parseAirportRoutesCacheRequest: parses canonical request with origin', () => {
  const parsed = parseAirportRoutesCacheRequest({
    origin: 'vcl',
  });

  assert.deepEqual(parsed, {
    originIata: 'VCL',
  });
});

Deno.test('parseAirportRoutesCacheRequest: supports originIata and origin_iata aliases', () => {
  assert.deepEqual(
    parseAirportRoutesCacheRequest({ originIata: 'han' }),
    { originIata: 'HAN' },
  );
  assert.deepEqual(
    parseAirportRoutesCacheRequest({ origin_iata: 'sgn' }),
    { originIata: 'SGN' },
  );
});

Deno.test('parseAirportRoutesCacheRequest: rejects invalid inputs', () => {
  assert.throws(
    () => parseAirportRoutesCacheRequest(null),
    /ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAirportRoutesCacheRequest(''),
    /ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAirportRoutesCacheRequest([]),
    /ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAirportRoutesCacheRequest({}),
    /ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAirportRoutesCacheRequest({ origin: 'VC' }),
    /ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAirportRoutesCacheRequest({ origin: 'VCLL' }),
    /ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAirportRoutesCacheRequest({ origin: '123' }),
    /ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAirportRoutesCacheRequest({ origin: 'VCL', extra: true }),
    /ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST/,
  );
});
