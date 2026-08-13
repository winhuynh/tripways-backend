import assert from 'node:assert/strict';
import { createAffiliateHandoffHandler } from '../handler.ts';

Deno.test('handoff handler returns only the resolved allowlisted response', async () => {
  const handler = createAffiliateHandoffHandler(async (id) => ({
    data: { url: 'https://www.aviasales.com/search', expires_at: '2026-08-19T00:00:00Z' },
    error: null,
  }));
  const response = await handler(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({ observationRef: 'obs_0123456789abcdef0123456789abcdef' }),
    }),
  );
  assert.equal(response.status, 200);
  assert.equal((await response.json()).data.url, 'https://www.aviasales.com/search');
});
