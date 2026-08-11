import assert from 'node:assert/strict';
import { mapRpcEnvelope } from '../rpc-envelope.ts';

Deno.test('shared envelope accepts one version-consistent successful response', () => {
  const value = { data: { page: true }, meta: { data_version: crypto.randomUUID() }, error: null };
  assert.deepEqual(mapRpcEnvelope(value, 'ERR_PAGE_CONTRACT'), value);
});

Deno.test('shared envelope rejects malformed and failed responses', () => {
  assert.throws(
    () => mapRpcEnvelope({ data: {}, meta: {}, error: null }, 'ERR_PAGE_CONTRACT'),
    /ERR_PAGE_CONTRACT/,
  );
  assert.throws(
    () =>
      mapRpcEnvelope(
        { data: null, meta: null, error: { code: 'ERR_PAGE_NOT_FOUND' } },
        'ERR_PAGE_CONTRACT',
      ),
    /ERR_PAGE_NOT_FOUND/,
  );
});
