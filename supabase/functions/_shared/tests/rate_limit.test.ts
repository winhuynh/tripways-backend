import assert from 'node:assert/strict';
import { buildRateLimitSubjectHashes, enforceSensitiveCommandRateLimit } from '../rate_limit.ts';

Deno.test('rate limit subjects hash user and trusted request IP separately', async () => {
  const request = new Request('https://example.test', {
    headers: { 'x-forwarded-for': '203.0.113.10, 10.0.0.1' },
  });

  const subjects = await buildRateLimitSubjectHashes('user-1', request);

  assert.equal(subjects.length, 2);
  assert.match(subjects[0] ?? '', /^[a-f0-9]{64}$/);
  assert.match(subjects[1] ?? '', /^[a-f0-9]{64}$/);
  assert.notEqual(subjects[0], subjects[1]);
  assert.equal(subjects.includes('user-1'), false);
  assert.equal(subjects.includes('203.0.113.10'), false);
});

Deno.test('rate limit uses a stable local IP subject when proxy header is absent', async () => {
  const request = new Request('https://example.test');
  const first = await buildRateLimitSubjectHashes('user-1', request);
  const second = await buildRateLimitSubjectHashes('user-1', request);

  assert.deepEqual(first, second);
});

Deno.test('sensitive command consumes user and IP quotas', async () => {
  const consumed: string[] = [];

  await enforceSensitiveCommandRateLimit({
    request: new Request('https://example.test'),
    userId: 'user-1',
    action: 'password_changed',
    consume: (subjectHash) => {
      consumed.push(subjectHash);
      return Promise.resolve({ allowed: true, remaining: 4, resetAt: 'later' });
    },
  });

  assert.equal(consumed.length, 2);
});

Deno.test('sensitive command rejects when either quota is exhausted', async () => {
  let calls = 0;

  await assert.rejects(
    () =>
      enforceSensitiveCommandRateLimit({
        request: new Request('https://example.test'),
        userId: 'user-1',
        action: 'delete_account',
        consume: () => {
          calls += 1;
          return Promise.resolve({
            allowed: calls === 1,
            remaining: 0,
            resetAt: 'later',
          });
        },
      }),
    /ERR_RATE_LIMITED/,
  );
  assert.equal(calls, 2);
});
