import assert from 'node:assert/strict';
import { parseRouteCacheRequest } from '../request.ts';

Deno.test('route cache request normalizes one bounded journey identity', () => {
  assert.deepEqual(
    parseRouteCacheRequest({
      origin: 'bkk',
      destination: 'lon',
      currency: 'usd',
      market: 'us',
      locale: 'en-GB',
    }),
    {
      origin: 'BKK',
      destination: 'LON',
      currency: 'USD',
      market: 'us',
      locale: 'en-GB',
    },
  );
});

Deno.test('route cache request accepts an origin-only city scope', () => {
  assert.deepEqual(
    parseRouteCacheRequest({
      origin: 'sgn',
      currency: 'usd',
      market: 'vn',
      locale: 'vi-VN',
    }),
    {
      origin: 'SGN',
      destination: null,
      currency: 'USD',
      market: 'vn',
      locale: 'vi-VN',
    },
  );
});

Deno.test('route cache request rejects unknown fields and invalid endpoints', () => {
  for (
    const input of [
      { origin: 'BKK', currency: 'USD', market: 'us', locale: 'en-GB', extra: true },
      { origin: 'BKK', destination: 'BKK', currency: 'USD', market: 'us', locale: 'en-GB' },
      { origin: 'B', currency: 'USD', market: 'us', locale: 'en-GB' },
      { origin: 'BKK', currency: 'US', market: 'us', locale: 'en-GB' },
    ]
  ) assert.throws(() => parseRouteCacheRequest(input), /ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST/);
});
