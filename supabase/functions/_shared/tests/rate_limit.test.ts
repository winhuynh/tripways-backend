import assert from 'node:assert/strict';
import { buildRateLimitSubjectHashes, createMemoryRateLimiter } from '../rate_limit.ts';

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

Deno.test('rate limit subjects prioritize cf-connecting-ip over x-forwarded-for', async () => {
  const request = new Request('https://example.test', {
    headers: {
      'cf-connecting-ip': '198.51.100.99',
      'x-forwarded-for': '203.0.113.10, 10.0.0.1',
    },
  });

  const subjects = await buildRateLimitSubjectHashes('test-action', request);
  const directCfRequest = new Request('https://example.test', {
    headers: { 'cf-connecting-ip': '198.51.100.99' },
  });
  const directSubjects = await buildRateLimitSubjectHashes('test-action', directCfRequest);

  assert.equal(subjects[1], directSubjects[1]);
});

Deno.test('rate limit uses a stable local IP subject when proxy header is absent', async () => {
  const request = new Request('https://example.test');
  const first = await buildRateLimitSubjectHashes('base-data-worker', request);
  const second = await buildRateLimitSubjectHashes('base-data-worker', request);

  assert.deepEqual(first, second);
});

Deno.test('createMemoryRateLimiter allows requests up to limit and throws ERR_RATE_LIMITED', async () => {
  const limiter = createMemoryRateLimiter({ limit: 2, windowMs: 10_000 });
  const request = new Request('https://example.test', {
    headers: { 'x-forwarded-for': '198.51.100.1' },
  });

  await limiter.consumeRequest('test-action', request);
  await limiter.consumeRequest('test-action', request);

  await assert.rejects(
    () => limiter.consumeRequest('test-action', request),
    /ERR_RATE_LIMITED/,
  );

  limiter.reset();
  await limiter.consumeRequest('test-action', request);
});
