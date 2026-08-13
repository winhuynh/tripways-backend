import assert from 'node:assert/strict';
import { executeRouteCache } from '../service.ts';

const input = {
  origin: 'BKK',
  destination: null,
  currency: 'USD',
  market: 'us',
  locale: 'en-GB',
};

Deno.test('route cache hit never calls Travelpayouts', async () => {
  let providerCalls = 0;
  const cached = { data: { status: 'available', routes: [{ to: 'LON' }] }, meta: {}, error: null };
  const result = await executeRouteCache(input, {
    read: () => Promise.resolve(cached),
    claim: () => Promise.reject(new Error('claim must not run')),
    load: () => {
      providerCalls += 1;
      throw new Error('provider must not run');
    },
    publish: () => Promise.reject(new Error('publish must not run')),
    fail: () => Promise.resolve(),
  });
  assert.deepEqual(result, cached);
  assert.equal(providerCalls, 0);
});

Deno.test('route cache miss claims, loads, and publishes exactly once', async () => {
  let providerCalls = 0;
  const filled = { data: { status: 'available', routes: [{ to: 'LON' }] }, meta: {}, error: null };
  const result = await executeRouteCache(input, {
    read: () => Promise.resolve({ data: { status: 'loading', routes: [] }, meta: {}, error: null }),
    claim: () => Promise.resolve({ action: 'refresh', leaseToken: 'lease_abc' }),
    load: () => {
      providerCalls += 1;
      return Promise.resolve({ ok: true as const, batch: { observations: [{ sourceId: 'one' }] } });
    },
    publish: (leaseToken, observations) => {
      assert.equal(leaseToken, 'lease_abc');
      assert.equal(observations.length, 1);
      return Promise.resolve(filled);
    },
    fail: () => Promise.resolve(),
  });
  assert.deepEqual(result, filled);
  assert.equal(providerCalls, 1);
});

Deno.test('route cache provider failure is finalized without leaking provider details', async () => {
  let failureCode = '';
  await assert.rejects(() =>
    executeRouteCache(input, {
      read: () =>
        Promise.resolve({ data: { status: 'loading', routes: [] }, meta: {}, error: null }),
      claim: () => Promise.resolve({ action: 'refresh', leaseToken: 'lease_abc' }),
      load: () =>
        Promise.resolve({ ok: false as const, issues: [{ code: 'ERR_PROVIDER_UNAVAILABLE' }] }),
      publish: () => Promise.reject(new Error('publish must not run')),
      fail: (_leaseToken, code) => {
        failureCode = code;
        return Promise.resolve();
      },
    }), /ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE/);
  assert.equal(failureCode, 'ERR_PROVIDER_UNAVAILABLE');
});
