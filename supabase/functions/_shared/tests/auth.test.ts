import assert from 'node:assert/strict';
import { requireUser } from '../auth.ts';

Deno.test('requireUser rejects a request without a bearer token', async () => {
  let calls = 0;
  const verifier = {
    getUser: () => {
      calls += 1;
      return Promise.resolve({ data: { user: null }, error: null });
    },
  };

  await assert.rejects(
    () => requireUser(new Request('https://example.test'), verifier),
    /ERR_UNAUTHORIZED/,
  );
  assert.equal(calls, 0);
});

Deno.test('requireUser verifies the bearer token with Supabase Auth', async () => {
  let receivedToken: string | undefined;
  const verifier = {
    getUser: (token: string) => {
      receivedToken = token;
      return Promise.resolve({
        data: { user: { id: 'user-1', email: 'user@example.test' } },
        error: null,
      });
    },
  };
  const request = new Request('https://example.test', {
    headers: { authorization: 'Bearer verified.jwt' },
  });

  const result = await requireUser(request, verifier);

  assert.equal(receivedToken, 'verified.jwt');
  assert.equal(result.jwt, 'verified.jwt');
  assert.equal(result.user.id, 'user-1');
});

Deno.test('requireUser rejects an Auth verification failure', async () => {
  const verifier = {
    getUser: () =>
      Promise.resolve({
        data: { user: null },
        error: { code: 'bad_jwt' },
      }),
  };
  const request = new Request('https://example.test', {
    headers: { authorization: 'Bearer invalid.jwt' },
  });

  await assert.rejects(() => requireUser(request, verifier), /ERR_UNAUTHORIZED/);
});
