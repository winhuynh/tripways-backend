import assert from 'node:assert/strict';
import { handleRouteCacheRequest } from '../handler.ts';

const body = {
  origin: 'BKK',
  destination: 'LON',
  currency: 'USD',
  market: 'us',
  locale: 'en-GB',
};

Deno.test('route cache handler lets a browser fill a miss after rate limiting', async () => {
  let allowRefresh = false;
  let rateLimits = 0;
  const response = await handleRouteCacheRequest(
    new Request('https://example.test/cache', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'user-agent': 'Mozilla/5.0' },
      body: JSON.stringify(body),
    }),
    {
      consume: () => {
        rateLimits += 1;
        return Promise.resolve({ allowed: true, remaining: 9, resetAt: new Date().toISOString() });
      },
      execute: (_input, canRefresh) => {
        allowRefresh = canRefresh;
        return Promise.resolve({
          data: { status: 'available', routes: [] },
          meta: {},
          error: null,
        });
      },
    },
  );
  assert.equal(response.status, 200);
  assert.equal(allowRefresh, true);
  assert.equal(rateLimits, 1);
});

Deno.test('route cache handler lets crawlers read cache but forbids provider refresh', async () => {
  let allowRefresh = true;
  const response = await handleRouteCacheRequest(
    new Request('https://example.test/cache', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'user-agent': 'Googlebot/2.1' },
      body: JSON.stringify(body),
    }),
    {
      consume: () => Promise.reject(new Error('crawler must not consume provider quota')),
      execute: (_input, canRefresh) => {
        allowRefresh = canRefresh;
        return Promise.resolve({ data: { status: 'loading', routes: [] }, meta: {}, error: null });
      },
    },
  );
  assert.equal(response.status, 200);
  assert.equal(allowRefresh, false);
});
