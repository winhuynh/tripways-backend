import assert from 'node:assert/strict';
import { executePriceEstimateIngestion } from '../service.ts';

Deno.test('price ingestion switches provider through registry without changing publication contract', async () => {
  let published: Record<string, unknown> = {};
  const result = await executePriceEstimateIngestion(
    { sourceCode: 'licensed_prices', providerKey: 'provider_b', idempotencyKey: 'estimate-0001' },
    new Map([['provider_b', {
      load: () =>
        Promise.resolve({
          ok: true as const,
          batch: {
            schemaVersion: 'route-price-estimates.v1' as const,
            sourceTime: null,
            estimates: [],
          },
        }),
    }]]),
    (args) => {
      published = args;
      return Promise.resolve({
        status: 'published',
        acceptedCount: 0,
        rejectedCount: 0,
        errorCode: null,
      });
    },
  );
  assert.equal(result.status, 'published');
  assert.equal(published.p_provider_version, 'route-price-estimates.v1');
  assert.equal(published.p_source_code, 'licensed_prices');
});

Deno.test('price ingestion fails closed for an unregistered provider key', async () => {
  await assert.rejects(
    () =>
      executePriceEstimateIngestion(
        { sourceCode: 'licensed_prices', providerKey: 'unknown', idempotencyKey: 'estimate-0002' },
        new Map(),
        () =>
          Promise.resolve({
            status: 'published',
            acceptedCount: 0,
            rejectedCount: 0,
            errorCode: null,
          }),
      ),
    /ERR_INGESTION_PROVIDER_NOT_CONFIGURED/,
  );
});
