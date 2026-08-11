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
      loadOurAirports: () => Promise.reject(new Error('must not call OurAirports')),
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
          loadOurAirports: () => Promise.reject(new Error('unused')),
          publish: () => Promise.reject(new Error('unused')),
        },
      ),
    /ERR_INGESTION_VALIDATION_FAILED/,
  );
});

Deno.test('ingestion service forwards OurAirports import metrics to publication', async () => {
  const captured: { rpcArguments: Record<string, unknown> | null } = { rpcArguments: null };
  await executeBaseDataIngestion(
    {
      sourceCode: 'ourairports',
      providerMode: 'ourairports',
      idempotencyKey: 'ourairports-2026-08-11',
    },
    {
      loadFixture: () => Promise.reject(new Error('unused')),
      loadApprovedApi: () => Promise.reject(new Error('unused')),
      loadOurAirports: () =>
        Promise.resolve({
          ok: true,
          batch: {
            schemaVersion: 'base-data.v1',
            sourceTime: '2026-08-11T00:00:00.000Z',
            countries: [],
            cities: [],
            airports: [],
            importMetadata: {
              sourceUrl: 'https://davidmegginson.github.io/ourairports-data/airports.csv',
              sourceEtag: '"snapshot-1"',
              sourceChecksum: 'a'.repeat(64),
              downloadedBytes: 10,
              rawRecordCount: 100,
              eligibleRecordCount: 10,
              filteredRecordCount: 90,
              invalidRecordCount: 0,
              filterVersion: 'ourairports-commercial.v1',
            },
          },
        }),
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

  assert.deepEqual(captured.rpcArguments?.p_import_metadata, {
    sourceUrl: 'https://davidmegginson.github.io/ourairports-data/airports.csv',
    sourceEtag: '"snapshot-1"',
    sourceChecksum: 'a'.repeat(64),
    downloadedBytes: 10,
    rawRecordCount: 100,
    eligibleRecordCount: 10,
    filteredRecordCount: 90,
    invalidRecordCount: 0,
    filterVersion: 'ourairports-commercial.v1',
  });
  assert.equal(captured.rpcArguments?.p_checksum, 'a'.repeat(64));
});

Deno.test('ingestion service preserves anomaly review error for operations', async () => {
  await assert.rejects(
    () =>
      executeBaseDataIngestion(
        {
          sourceCode: 'ourairports',
          providerMode: 'ourairports',
          idempotencyKey: 'ourairports-2026-08-12',
        },
        {
          loadFixture: () => Promise.reject(new Error('unused')),
          loadApprovedApi: () => Promise.reject(new Error('unused')),
          loadOurAirports: () =>
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
          publish: () =>
            Promise.resolve({
              status: 'awaiting_review',
              acceptedCount: 0,
              rejectedCount: 10,
              errorCode: 'ERR_INGESTION_ANOMALY_REVIEW_REQUIRED',
            }),
        },
      ),
    /ERR_INGESTION_ANOMALY_REVIEW_REQUIRED/,
  );
});
