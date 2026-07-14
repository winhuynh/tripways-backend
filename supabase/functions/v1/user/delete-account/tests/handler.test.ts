import assert from 'node:assert/strict';
import { type DeleteAccountHandlerDependencies, handleDeleteAccountRequest } from '../handler.ts';

function dependencies(
  overrides: Partial<DeleteAccountHandlerDependencies> = {},
): DeleteAccountHandlerDependencies {
  return {
    authenticate: () =>
      Promise.resolve({
        user: { id: 'verified-user', email: 'current@example.test' },
        jwt: 'verified.jwt',
      }),
    execute: () => Promise.resolve({ messageCode: 'ACCOUNT_DELETED' }),
    log: () => {},
    ...overrides,
  };
}

Deno.test('delete handler returns stable success without UUID', async () => {
  const response = await handleDeleteAccountRequest(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({ current_password: 'old' }),
    }),
    dependencies(),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body, {
    data: { message_code: 'ACCOUNT_DELETED' },
    error: null,
  });
  assert.equal(JSON.stringify(body).includes('verified-user'), false);
});
