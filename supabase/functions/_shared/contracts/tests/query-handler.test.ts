import assert from 'node:assert/strict';
import { createQueryHandler } from '../query-handler.ts';

Deno.test('shared query handler parses, calls one RPC dependency, and maps the envelope', async () => {
  let calls = 0;
  const handler = createQueryHandler({
    parse: () => ({ key: 'bangkok' }),
    query: (input) => {
      calls += 1;
      return Promise.resolve({
        data: input,
        meta: { data_version: crypto.randomUUID() },
        error: null,
      });
    },
    contractErrorCode: 'ERR_PAGE_CONTRACT',
  });
  const response = await handler(
    new Request('https://example.com', { method: 'POST', body: '{}' }),
  );
  assert.equal(response.status, 200);
  assert.equal(calls, 1);
});

Deno.test('shared query handler keeps malformed requests behind stable errors', async () => {
  const handler = createQueryHandler({
    parse: () => {
      throw new Error('ERR_PAGE_INVALID_REQUEST');
    },
    query: () => Promise.reject(new Error('unreachable')),
    contractErrorCode: 'ERR_PAGE_CONTRACT',
  });
  const response = await handler(
    new Request('https://example.com', { method: 'POST', body: '{}' }),
  );
  assert.equal(response.status, 400);
});

Deno.test('cacheable query handler preserves the RPC envelope shape', async () => {
  const envelope = {
    data: { city: { slug: 'bangkok' } },
    meta: { data_version: crypto.randomUUID() },
    error: null,
  };
  const handler = createQueryHandler({
    parse: () => ({ key: 'bangkok' }),
    query: () => Promise.resolve(envelope),
    contractErrorCode: 'ERR_PAGE_CONTRACT',
    cacheable: true,
  });

  const response = await handler(
    new Request('https://example.com', { method: 'POST', body: '{}' }),
  );

  assert.equal(response.status, 200);
  assert.match(response.headers.get('cache-control') ?? '', /s-maxage=86400/);
  assert.deepEqual(await response.json(), envelope);
});
