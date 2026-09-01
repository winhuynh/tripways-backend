import assert from 'node:assert/strict';
import { parseRouteSearchRequest } from '@shared/contracts/route-filters.ts';
import { toRouteSearchRpcInput } from '../rpc-input.ts';

Deno.test('route search transport maps canonical camelCase contract once', () => {
  const request = parseRouteSearchRequest({
    scope: { type: 'origin_city', key: 'bangkok' },
    filters: {
      max_stops: 0,
      airlines: ['vn'],
      connection_airports: ['sin'],
      departure_airports: ['sgn'],
      destination_countries: ['gb'],
      destination_regions: ['Europe'],
      counterpart_query: 'london',
      counterpart_countries: ['gb'],
      counterpart_regions: ['Europe'],
      departure_time_buckets: ['morning'],
      days_of_week: [1, 5],
      route_type: 'international',
      max_duration_minutes: 900,
      max_layover_minutes: 180,
      cabin: 'economy',
      price_max: 900,
      currency: 'USD',
    },
    page_size: 20,
    after: null,
  });
  const result = toRouteSearchRpcInput(request);
  assert.equal(result.scope.type, 'origin_city');
  if (result.scope.type === 'origin_city') {
    assert.equal(result.scope.key, 'bangkok');
  }
  assert.deepEqual(result.filters, {
    max_stops: 0,
    airlines: ['VN'],
    connection_airports: ['SIN'],
    departure_airports: ['SGN'],
    destination_countries: ['GB'],
    destination_regions: ['Europe'],
    counterpart_query: 'london',
    counterpart_countries: ['GB'],
    counterpart_regions: ['Europe'],
    departure_time_buckets: ['morning'],
    days_of_week: [1, 5],
    route_type: 'international',
    max_duration_minutes: 900,
    max_layover_minutes: 180,
    cabin: 'economy',
    max_amount: 900,
    currency: 'USD',
  });
  assert.equal(result.page_size, 20);
  assert.equal(result.after, null);
});

Deno.test('route search transport omits null and empty optional filters', () => {
  const request = parseRouteSearchRequest({
    scope: { type: 'global' },
    filters: {},
  });

  assert.deepEqual(toRouteSearchRpcInput(request).filters, {
    max_stops: 1,
    route_type: 'all',
    cabin: 'any',
  });
});
