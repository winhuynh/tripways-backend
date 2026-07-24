import assert from 'node:assert/strict';
import { handleRouteQuery, type RouteQueryDependencies } from '../handler.ts';

const route = {
  id: 'route-1',
  from: 'SGN',
  to: 'SIN',
  stops: 0,
  connection_airports: [],
  operating_airlines: ['SQ'],
  total_flight_minutes: 125,
  layover_minutes: null,
  total_duration_minutes: 125,
  departure_local_time: '09:00',
  arrival_local_time: '12:05',
  arrival_day_offset: 0,
  valid_from: '2026-01-01',
  valid_to: '2026-12-31',
  days_of_week: [1],
  confidence_score: 0.95,
  data_version: 'fixture-v1',
};

function dependencies(overrides: Partial<RouteQueryDependencies> = {}): RouteQueryDependencies {
  return {
    searchRoutes: () =>
      Promise.resolve({
        data: [route],
        meta: {
          total: 1,
          limit: 20,
          offset: 0,
          facets: { stops: [{ value: 0, count: 1 }], airlines: [{ value: 'SQ', count: 1 }] },
        },
        error: null,
      }),
    ...overrides,
  };
}

Deno.test('POST route query forwards normalized input and returns the public envelope', async () => {
  let receivedInput: unknown;
  const response = await handleRouteQuery(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({
        action: 'search_routes',
        input: { from: 'sgn', to: 'sin' },
      }),
    }),
    dependencies({
      searchRoutes: (input) => {
        receivedInput = input;
        return dependencies().searchRoutes(input);
      },
    }),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(receivedInput, { from: 'SGN', to: 'SIN', limit: 20, offset: 0 });
  assert.equal((await response.json()).status, 'success');
});

Deno.test('route query maps public validation, unavailable, and contract errors', async () => {
  const invalid = await handleRouteQuery(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({ action: 'search_routes', input: { from: 'SGN', to: 'SGN' } }),
    }),
    dependencies(),
  );
  assert.equal(invalid.status, 400);

  for (
    const [code, expectedStatus] of [
      ['ERR_ROUTE_DISCOVERY_UNAVAILABLE', 503],
      ['ERR_ROUTE_DISCOVERY_CONTRACT', 500],
    ] as const
  ) {
    const response = await handleRouteQuery(
      new Request('https://example.test', {
        method: 'POST',
        body: JSON.stringify({ action: 'search_routes', input: { from: 'SGN', to: 'SIN' } }),
      }),
      dependencies({ searchRoutes: () => Promise.reject(new Error(code)) }),
    );
    assert.equal(response.status, expectedStatus);
  }
});

Deno.test('route query rejects unsupported methods and malformed JSON', async () => {
  const getResponse = await handleRouteQuery(
    new Request('https://example.test', { method: 'GET' }),
    dependencies(),
  );
  const invalidJsonResponse = await handleRouteQuery(
    new Request('https://example.test', { method: 'POST', body: '{' }),
    dependencies(),
  );
  assert.equal(getResponse.status, 405);
  assert.equal(invalidJsonResponse.status, 400);
});
