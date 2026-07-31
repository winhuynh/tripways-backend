import assert from 'node:assert/strict';
import { parseBaseDataIngestionRequest } from '../request.ts';

Deno.test('ingestion request requires a bounded idempotency key and allowed mode', () => {
  const parsed = parseBaseDataIngestionRequest(
    { sourceCode: 'p0a_fixture', providerMode: 'fixture' },
    'p0a-idempotency-001',
  );

  assert.deepEqual(parsed, {
    sourceCode: 'p0a_fixture',
    providerMode: 'fixture',
    idempotencyKey: 'p0a-idempotency-001',
  });
});

Deno.test('ingestion request rejects arbitrary provider modes and source codes', () => {
  assert.throws(
    () =>
      parseBaseDataIngestionRequest(
        { sourceCode: 'https://evil.test', providerMode: 'remote_url' },
        'p0a-idempotency-001',
      ),
    /ERR_INGESTION_INVALID_REQUEST/,
  );
});
