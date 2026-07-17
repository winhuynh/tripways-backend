import assert from 'node:assert/strict';
import { handleRouteQuery, type RouteQueryDependencies } from '../handler.ts';

function dependencies(
  overrides: Partial<RouteQueryDependencies> = {},
): RouteQueryDependencies {
  return {
    searchRoutes: () =>
      Promise.resolve({
        data: [{ id: 'route-option-1' }],
        meta: { total: 1, facets: { stops: [], airlines: [] } },
        error: null,
      }),
    ...overrides,
  };
}

Deno.test('POST route query forwards validated filters and returns the RPC envelope', async () => {
  let receivedInput: Record<string, unknown> | undefined;
  const response = await handleRouteQuery(
    new Request('https://example.test', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ from: 'SGN', to: 'LHR', max_stops: 1 }),
    }),
    dependencies({
      searchRoutes: (input) => {
        receivedInput = input;
        return Promise.resolve({ data: [], meta: { total: 0 }, error: null });
      },
    }),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(receivedInput, { from: 'SGN', to: 'LHR', max_stops: 1 });
  assert.deepEqual(await response.json(), {
    data: [],
    meta: { total: 0 },
    error: null,
  });
});

Deno.test('route query maps stable RPC validation and not-found errors', async () => {
  for (
    const [code, expectedStatus] of [
      ['ERR_INVALID_REQUEST', 400],
      ['ERR_AIRPORT_NOT_FOUND', 404],
    ] as const
  ) {
    const response = await handleRouteQuery(
      new Request('https://example.test', {
        method: 'POST',
        body: JSON.stringify({ from: 'SGN', to: 'LHR' }),
      }),
      dependencies({
        searchRoutes: () =>
          Promise.resolve({
            data: [],
            meta: {},
            error: { code, message: 'Database-owned detail' },
          }),
      }),
    );

    assert.equal(response.status, expectedStatus);
    assert.deepEqual(await response.json(), { data: null, error: { code } });
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
