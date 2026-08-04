import assert from 'node:assert/strict';
import { parseRouteSearchRequest } from '../route-filters.ts';

Deno.test('canonical route search normalizes every reusable filter', () => {
  const result = parseRouteSearchRequest({
    scope: { type: 'city_pair', from: 'ho-chi-minh-city', to: 'london' },
    filters: {
      max_stops: 3,
      airlines: ['vn', 'VN'],
      connection_airports: ['sin'],
      max_duration_minutes: 1200,
      max_layover_minutes: 300,
      cabin: 'economy',
      price_max: 900,
      currency: 'usd',
    },
    page_size: 20,
    after: null,
  });
  assert.deepEqual(result.scope, {
    type: 'city_pair',
    from: 'ho-chi-minh-city',
    to: 'london',
  });
  assert.deepEqual(result.filters.airlines, ['VN']);
  assert.deepEqual(result.filters.connectionAirports, ['SIN']);
  assert.equal(result.filters.currency, 'USD');
});

Deno.test('canonical route search rejects unknown fields and invalid scope', () => {
  assert.throws(
    () => parseRouteSearchRequest({ scope: { type: 'global' }, filters: {}, offset: 10 }),
    /ERR_ROUTE_SEARCH_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseRouteSearchRequest({ scope: { type: 'origin_airport', key: 'SG' }, filters: {} }),
    /ERR_ROUTE_SEARCH_INVALID_REQUEST/,
  );
});
