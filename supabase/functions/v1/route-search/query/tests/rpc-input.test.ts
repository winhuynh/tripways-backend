import assert from 'node:assert/strict';
import { toRouteSearchRpcInput } from '../rpc-input.ts';

Deno.test('route search transport maps canonical camelCase contract once', () => {
  const result = toRouteSearchRpcInput({
    scope: { type: 'origin_city', key: 'bangkok' },
    filters: {
      maxStops: 3,
      airlines: ['TG'],
      connectionAirports: ['SIN'],
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
  assert.equal(result.page_size, 20);
});
