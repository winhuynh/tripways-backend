import assert from 'node:assert/strict';
import { toRouteSearchRpcInput } from '../rpc-input.ts';

Deno.test('route search transport maps canonical camelCase contract once', () => {
  const result = toRouteSearchRpcInput({
    scope: { type: 'origin_city', key: 'bangkok' },
    filters: {
      maxStops: 3,
      airlines: ['TG'],
      connectionAirports: ['SIN'],
      departureAirports: ['BKK'],
      destinationCountries: ['GB'],
      destinationRegions: ['Europe'],
      counterpartQuery: 'sin',
      counterpartCountries: ['SG'],
      counterpartRegions: ['Asia'],
      departureTimeBuckets: ['morning'],
      routeType: 'international',
      maxDurationMinutes: 1200,
      maxLayoverMinutes: 300,
      cabin: 'economy',
      priceMax: 900,
      currency: 'USD',
    },
    pageSize: 20,
    after: null,
  });
  assert.equal(result.filters.max_stops, 3);
  assert.deepEqual(result.filters.connection_airports, ['SIN']);
  assert.deepEqual(result.filters.departure_airports, ['BKK']);
  assert.deepEqual(result.filters.destination_countries, ['GB']);
  assert.deepEqual(result.filters.destination_regions, ['Europe']);
  assert.equal(result.filters.counterpart_query, 'sin');
  assert.deepEqual(result.filters.counterpart_countries, ['SG']);
  assert.deepEqual(result.filters.counterpart_regions, ['Asia']);
  assert.deepEqual(result.filters.departure_time_buckets, ['morning']);
  assert.equal(result.filters.route_type, 'international');
  assert.equal(result.page_size, 20);
});
