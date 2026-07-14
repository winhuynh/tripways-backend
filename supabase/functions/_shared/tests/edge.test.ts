import assert from 'node:assert/strict';
import { assertMethod, errorResponse, jsonResponse, readJson } from '../edge.ts';

Deno.test('assertMethod returns a stable method error', async () => {
  const response = assertMethod(new Request('https://example.test'), ['POST']);

  assert.equal(response?.status, 405);
  assert.deepEqual(await response?.json(), {
    data: null,
    error: { code: 'ERR_METHOD_NOT_ALLOWED' },
  });
});

Deno.test('readJson rejects malformed JSON with a stable code', async () => {
  const request = new Request('https://example.test', {
    method: 'POST',
    body: '{',
  });

  await assert.rejects(() => readJson(request), /ERR_REQUEST_JSON_INVALID/);
});

Deno.test('errorResponse maps known errors without leaking unknown details', async () => {
  const unauthorized = errorResponse(new Error('ERR_UNAUTHORIZED'));
  const unknown = errorResponse(new Error('database password=secret failed'));

  assert.equal(unauthorized.status, 401);
  assert.deepEqual(await unauthorized.json(), {
    data: null,
    error: { code: 'ERR_UNAUTHORIZED' },
  });
  assert.equal(unknown.status, 500);
  assert.deepEqual(await unknown.json(), {
    data: null,
    error: { code: 'ERR_INTERNAL' },
  });
});

Deno.test('jsonResponse disables caching', () => {
  const response = jsonResponse({ ok: true });

  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('content-type'), 'application/json; charset=utf-8');
});
