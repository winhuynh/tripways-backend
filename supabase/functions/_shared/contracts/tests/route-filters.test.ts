import assert from 'node:assert/strict';
import { parseRouteSearchRequest } from '../route-filters.ts';

Deno.test('canonical route search normalizes every reusable filter', () => {
  const result = parseRouteSearchRequest({
    scope: { type: 'city_pair', from: 'ho-chi-minh-city', to: 'london' },
    filters: {
      max_stops: 3,
      airlines: ['vn', 'VN'],
      connection_airports: ['sin'],
      departure_airports: ['bkk'],
      destination_countries: ['gb'],
      destination_regions: ['Europe'],
      counterpart_query: '  sin ',
      counterpart_countries: ['sg'],
      counterpart_regions: ['Asia'],
      departure_time_buckets: ['morning'],
      route_type: 'international',
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
  assert.deepEqual(result.filters.departureAirports, ['BKK']);
  assert.deepEqual(result.filters.destinationCountries, ['GB']);
  assert.deepEqual(result.filters.destinationRegions, ['Europe']);
  assert.equal(result.filters.counterpartQuery, 'sin');
  assert.deepEqual(result.filters.counterpartCountries, ['SG']);
  assert.deepEqual(result.filters.counterpartRegions, ['Asia']);
  assert.deepEqual(result.filters.departureTimeBuckets, ['morning']);
  assert.equal(result.filters.routeType, 'international');
  assert.equal(result.filters.currency, 'USD');
});

Deno.test('airport route search accepts a verified direction scope', () => {
  const result = parseRouteSearchRequest({
    scope: { type: 'airport', key: 'bkk', direction: 'to' },
    filters: { counterpart_query: 'singapore' },
  });
  assert.deepEqual(result.scope, { type: 'airport', key: 'BKK', direction: 'to' });
  assert.equal(result.filters.maxStops, 3);
  assert.equal(result.filters.counterpartQuery, 'singapore');
  assert.throws(
    () =>
      parseRouteSearchRequest({
        scope: { type: 'airport', key: 'BKK', direction: 'from' },
        filters: { max_stops: 1 },
      }),
    /ERR_ROUTE_SEARCH_INVALID_REQUEST/,
  );
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
