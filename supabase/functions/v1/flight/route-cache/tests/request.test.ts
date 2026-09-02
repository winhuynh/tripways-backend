import assert from 'node:assert/strict';
import { parseRouteCacheRequest } from '../request.ts';

Deno.test('parseRouteCacheRequest: parses canonical request with origin and destination', () => {
  const parsed = parseRouteCacheRequest({
    origin: 'bkk',
    destination: 'lon',
    currency: 'usd',
    market: 'us',
    locale: 'en-GB',
  });

  assert.deepEqual(parsed, {
    originIata: 'BKK',
    destIata: 'LON',
    currency: 'USD',
    market: 'us',
    locale: 'en-GB',
  });
});

Deno.test('parseRouteCacheRequest: parses request with origin only and defaults', () => {
  const parsed = parseRouteCacheRequest({
    originIata: 'BKK',
  });

  assert.deepEqual(parsed, {
    originIata: 'BKK',
    currency: 'USD',
    market: 'us',
  });
});

Deno.test('parseRouteCacheRequest: supports aliased property names', () => {
  const parsed = parseRouteCacheRequest({
    origin_iata: 'bkk',
    destination_iata: 'cdg',
    currency_code: 'eur',
    market_code: 'FR',
  });

  assert.deepEqual(parsed, {
    originIata: 'BKK',
    destIata: 'CDG',
    currency: 'EUR',
    market: 'fr',
  });
});

Deno.test('parseRouteCacheRequest: throws on invalid inputs', () => {
  // Non-object
  assert.throws(() => parseRouteCacheRequest(null), /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/);
  assert.throws(() => parseRouteCacheRequest(''), /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/);
  assert.throws(() => parseRouteCacheRequest([]), /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/);

  // Missing origin
  assert.throws(() => parseRouteCacheRequest({}), /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/);

  // Invalid origin IATA
  assert.throws(
    () => parseRouteCacheRequest({ origin: 'BK' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseRouteCacheRequest({ origin: 'BKKK' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseRouteCacheRequest({ origin: '12' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );

  // Invalid destination IATA
  assert.throws(
    () => parseRouteCacheRequest({ origin: 'BKK', destination: 'L' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );

  // Same origin and destination
  assert.throws(
    () => parseRouteCacheRequest({ origin: 'BKK', destination: 'bkk' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );

  // Invalid currency
  assert.throws(
    () => parseRouteCacheRequest({ origin: 'BKK', currency: 'US' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );

  // Invalid market
  assert.throws(
    () => parseRouteCacheRequest({ origin: 'BKK', market: 'USA' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );

  // Invalid locale
  assert.throws(
    () =>
      parseRouteCacheRequest({ origin: 'BKK', locale: 'too-long-locale-string-exceeding-bounds' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );

  // Unknown fields
  assert.throws(
    () => parseRouteCacheRequest({ origin: 'BKK', extraField: 'bad' }),
    /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/,
  );
});
