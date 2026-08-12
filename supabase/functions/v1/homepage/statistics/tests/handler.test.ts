import assert from 'node:assert/strict';
import { createHomepageStatisticsHandler } from '../handler.ts';

Deno.test('homepage statistics handler returns the canonical RPC envelope', async () => {
  const handler = createHomepageStatisticsHandler(async () => ({
    data: {
      origin_city_count: 3,
      origin_airport_count: 4,
      published_direct_route_count: 6,
    },
    meta: { data_version: 'version-1' },
    error: null,
  }));

  const response = await handler(
    new Request('http://local', {
      method: 'POST',
      body: '{}',
    }),
  );

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control')?.includes('public'), true);
  assert.equal((await response.json()).data.published_direct_route_count, 6);
});

Deno.test('homepage statistics handler rejects non-empty input', async () => {
  const handler = createHomepageStatisticsHandler(async () => ({
    data: {},
    meta: {},
    error: null,
  }));
  const response = await handler(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({ unexpected: true }),
    }),
  );
  assert.equal(response.status, 400);
});
