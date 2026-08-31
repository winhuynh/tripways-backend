import assert from 'node:assert/strict';
import { buildRateLimitSubjectHashes } from '../rate_limit.ts';

Deno.test('rate limit subjects hash worker/action and trusted request IP separately', async () => {
  const request = new Request('https://example.test', {
    headers: { 'x-forwarded-for': '203.0.113.10, 10.0.0.1' },
  });

  const subjects = await buildRateLimitSubjectHashes('base-data-worker', request);

  assert.equal(subjects.length, 2);
  assert.match(subjects[0] ?? '', /^[a-f0-9]{64}$/);
  assert.match(subjects[1] ?? '', /^[a-f0-9]{64}$/);
  assert.notEqual(subjects[0], subjects[1]);
  assert.equal(subjects.includes('base-data-worker'), false);
  assert.equal(subjects.includes('203.0.113.10'), false);
});

Deno.test('rate limit uses a stable local IP subject when proxy header is absent', async () => {
  const request = new Request('https://example.test');
  const first = await buildRateLimitSubjectHashes('base-data-worker', request);
  const second = await buildRateLimitSubjectHashes('base-data-worker', request);

  assert.deepEqual(first, second);
});
