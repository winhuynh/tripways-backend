import assert from 'node:assert/strict';
import { parseRouteSearchRequest } from '../request.ts';

Deno.test('route query normalizes the action request and defaults pagination', () => {
  assert.deepEqual(
    parseRouteSearchRequest({
      action: 'search_routes',
      input: {
        from: 'sgn',
        to: 'sin',
        max_stops: 1,
        airlines: ['sq', 'SQ'],
      },
    }),
    {
      action: 'search_routes',
      input: {
        from: 'SGN',
        to: 'SIN',
        max_stops: 1,
        airlines: ['SQ'],
        limit: 20,
        offset: 0,
      },
    },
  );
});

Deno.test('route query rejects invalid action and route identity', () => {
  for (
    const value of [
      { action: 'legacy', input: { from: 'SGN', to: 'SIN' } },
      { action: 'search_routes', input: { from: 'SG', to: 'SIN' } },
      { action: 'search_routes', input: { from: 'SGN', to: 'sgn' } },
      { action: 'search_routes', input: { from: 'SGN', to: 'SIN', max_stops: 2 } },
      { action: 'search_routes', input: { from: 'SGN', to: 'SIN', limit: 0 } },
      { action: 'search_routes', input: { from: 'SGN', to: 'SIN', offset: -1 } },
      { action: 'search_routes', input: { from: 'SGN', to: 'SIN', secret: true } },
    ]
  ) {
    assert.throws(
      () => parseRouteSearchRequest(value),
      /ERR_ROUTE_DISCOVERY_INVALID_REQUEST/,
    );
  }
});
