import assert from 'node:assert/strict';
import { parseRouteSearchRequest } from '../request.ts';

Deno.test('route query accepts the documented filter shape without domain decisions', () => {
  const input = {
    from: 'sgn',
    to: 'LHR',
    max_stops: 1,
    airlines: ['SQ'],
    exclude_airports: ['BKK'],
    max_duration_minutes: 1200,
    max_layover_minutes: 240,
    departure_window: 'morning',
    limit: 20,
    offset: 0,
  };

  assert.deepEqual(parseRouteSearchRequest(input), input);
});

Deno.test('route query rejects unknown fields and invalid transport types', () => {
  assert.throws(
    () => parseRouteSearchRequest({ from: 'SGN', to: 'LHR', provider_key: 'secret' }),
    /ERR_ROUTE_SEARCH_REQUEST_INVALID/,
  );
  assert.throws(
    () => parseRouteSearchRequest({ from: 'SGN', to: 'LHR', airlines: 'SQ' }),
    /ERR_ROUTE_SEARCH_REQUEST_INVALID/,
  );
  assert.throws(
    () => parseRouteSearchRequest([]),
    /ERR_ROUTE_SEARCH_REQUEST_INVALID/,
  );
});
