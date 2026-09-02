import assert from 'node:assert/strict';
import {
  handleRouteIngestionRequest,
  parseRouteIngestionRequest,
  type RouteIngestionLogEvent,
} from '../handler.ts';

Deno.test('parseRouteIngestionRequest validates airport IATAs and scope', () => {
  const parsed = parseRouteIngestionRequest({ airports: ['sgn', 'sin', 'LHR', 'invalid'] });
  assert.deepEqual(parsed.airports, ['SGN', 'SIN', 'LHR']);

  const scoped = parseRouteIngestionRequest({ scope: 'top_airports', limit: 300 });
  assert.equal(scoped.scope, 'top_airports');
  assert.equal(scoped.limit, 300);

  assert.throws(() => parseRouteIngestionRequest(null), /ERR_INVALID_REQUEST/);
  assert.throws(() => parseRouteIngestionRequest({}), /ERR_INVALID_REQUEST/);
  assert.throws(() => parseRouteIngestionRequest({ airports: [] }), /ERR_INVALID_REQUEST/);
});

Deno.test('handleRouteIngestionRequest rejects unauthorized requests without valid bearer', async () => {
  const req = new Request('http://localhost/ingest', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ airports: ['SGN'] }),
  });

  const logs: RouteIngestionLogEvent[] = [];

  const res = await handleRouteIngestionRequest(req, {
    workerSecret: 'valid-secret-key-12345678',
    execute() {
      return Promise.resolve({
        status: 'success',
        total_airports_processed: 1,
        total_routes_upserted: 1,
        results: [],
        errors: [],
      });
    },
    log(event) {
      logs.push(event);
    },
  });

  assert.equal(res.status, 401);
  const json = await res.json();
  assert.equal(json.error.code, 'ERR_INGESTION_UNAUTHORIZED');
  assert.equal(logs.length, 1);
  const [firstLog] = logs;
  assert.ok(firstLog !== undefined);
  assert.equal(firstLog.status, 'failed');
});

Deno.test('handleRouteIngestionRequest processes valid authenticated request', async () => {
  const req = new Request('http://localhost/ingest', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer valid-secret-key-12345678',
    },
    body: JSON.stringify({ airports: ['SGN', 'SIN'] }),
  });

  const logs: RouteIngestionLogEvent[] = [];

  const res = await handleRouteIngestionRequest(req, {
    workerSecret: 'valid-secret-key-12345678',
    execute(payload) {
      return Promise.resolve({
        status: 'success',
        total_airports_processed: payload.airports?.length ?? 0,
        total_routes_upserted: 5,
        results: [],
        errors: [],
      });
    },
    log(event) {
      logs.push(event);
    },
  });

  assert.equal(res.status, 200);
  const json = await res.json();
  assert.equal(json.data.total_airports_processed, 2);
  assert.equal(json.data.total_routes_upserted, 5);
  assert.equal(logs.length, 1);
  const [successLog] = logs;
  assert.ok(successLog !== undefined);
  assert.equal(successLog.status, 'succeeded');
});
