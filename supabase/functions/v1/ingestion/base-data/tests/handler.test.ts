import assert from 'node:assert/strict';
import { handleBaseDataIngestionRequest } from '../handler.ts';

function request(headers: Record<string, string> = {}): Request {
  return new Request('http://localhost/functions/v1/ingestion/base-data', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'idempotency-key': 'p0a-idempotency-001',
      ...headers,
    },
    body: JSON.stringify({ sourceCode: 'p0a_fixture', providerMode: 'fixture' }),
  });
}

Deno.test('ingestion handler rejects missing worker secret', async () => {
  const response = await handleBaseDataIngestionRequest(request(), {
    workerSecret: 'local-worker-secret',
    rateLimit: () => Promise.resolve(),
    execute: () => Promise.reject(new Error('must not execute')),
    log: () => undefined,
  });

  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, 'ERR_INGESTION_UNAUTHORIZED');
});

Deno.test('ingestion handler rate limits hashed worker and IP identities', async () => {
  const subjects: string[] = [];
  const response = await handleBaseDataIngestionRequest(
    request({
      authorization: 'Bearer local-worker-secret',
      'x-forwarded-for': '203.0.113.9, 10.0.0.1',
    }),
    {
      workerSecret: 'local-worker-secret',
      rateLimit: (subjectHash) => {
        subjects.push(subjectHash);
        return Promise.resolve();
      },
      execute: () =>
        Promise.resolve({
          status: 'published',
          acceptedCount: 3,
          rejectedCount: 0,
          errorCode: null,
        }),
      log: () => undefined,
    },
  );

  assert.equal(response.status, 200);
  assert.equal(subjects.length, 2);
  assert.ok(subjects.every((subject) => /^[a-f0-9]{64}$/.test(subject)));
  assert.ok(subjects.every((subject) => !subject.includes('203.0.113.9')));
});

Deno.test('ingestion logs contain stable metadata but no secret, IP, or payload', async () => {
  const events: unknown[] = [];
  await handleBaseDataIngestionRequest(
    request({
      authorization: 'Bearer local-worker-secret',
      'x-forwarded-for': '203.0.113.9',
      'x-client-request-id': 'client-001',
    }),
    {
      workerSecret: 'local-worker-secret',
      rateLimit: () => Promise.resolve(),
      execute: () => Promise.reject(new Error('ERR_INGESTION_PUBLISH_FAILED')),
      log: (event) => events.push(event),
    },
  );

  const serialized = JSON.stringify(events);
  assert.match(serialized, /INGEST_BASE_DATA/);
  assert.match(serialized, /ERR_INGESTION_PUBLISH_FAILED/);
  assert.doesNotMatch(serialized, /local-worker-secret|203\.0\.113\.9|sourceCode/);
});

Deno.test('ingestion handler returns a stable conflict for anomaly review', async () => {
  const response = await handleBaseDataIngestionRequest(
    request({ authorization: 'Bearer local-worker-secret' }),
    {
      workerSecret: 'local-worker-secret',
      rateLimit: () => Promise.resolve(),
      execute: () => Promise.reject(new Error('ERR_INGESTION_ANOMALY_REVIEW_REQUIRED')),
      log: () => undefined,
    },
  );

  assert.equal(response.status, 409);
  assert.equal((await response.json()).error.code, 'ERR_INGESTION_ANOMALY_REVIEW_REQUIRED');
});
