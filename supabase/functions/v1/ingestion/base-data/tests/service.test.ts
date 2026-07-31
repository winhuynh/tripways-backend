import assert from 'node:assert/strict';
import { executeBaseDataIngestion } from '../service.ts';

Deno.test('ingestion service sends canonical fixture and checksum to publication RPC', async () => {
  const captured: { rpcArguments: Record<string, unknown> | null } = { rpcArguments: null };
  const result = await executeBaseDataIngestion(
    {
      sourceCode: 'p0a_fixture',
      providerMode: 'fixture',
      idempotencyKey: 'p0a-idempotency-001',
    },
    {
      loadFixture: () =>
        Promise.resolve({
          ok: true,
          batch: {
            schemaVersion: 'base-data.v1',
            sourceTime: null,
            countries: [],
            cities: [],
            airports: [],
          },
        }),
      loadApprovedApi: () => Promise.reject(new Error('must not call approved API')),
      publish: (arguments_) => {
        captured.rpcArguments = arguments_;
        return Promise.resolve({
          status: 'published',
          acceptedCount: 0,
          rejectedCount: 0,
          errorCode: null,
        });
      },
    },
  );

  assert.equal(result.status, 'published');
  assert.equal(captured.rpcArguments?.p_source_code, 'p0a_fixture');
  assert.match(String(captured.rpcArguments?.p_checksum), /^[a-f0-9]{64}$/);
});

Deno.test('ingestion service maps provider issues to stable validation failure', async () => {
  await assert.rejects(
    () =>
      executeBaseDataIngestion(
        {
          sourceCode: 'p0a_fixture',
          providerMode: 'fixture',
          idempotencyKey: 'p0a-idempotency-001',
        },
        {
          loadFixture: () =>
            Promise.resolve({
              ok: false,
              issues: [{
                code: 'ERR_INVALID_COORDINATES',
                recordType: 'airport',
                sourceKey: 'broken',
              }],
            }),
          loadApprovedApi: () => Promise.reject(new Error('unused')),
          publish: () => Promise.reject(new Error('unused')),
        },
      ),
    /ERR_INGESTION_VALIDATION_FAILED/,
  );
});
