import assert from 'node:assert/strict';
import {
  type AccountSecurityHandlerDependencies,
  handleAccountSecurityRequest,
} from '../handler.ts';

function dependencies(
  overrides: Partial<AccountSecurityHandlerDependencies> = {},
): AccountSecurityHandlerDependencies {
  return {
    authenticate: () =>
      Promise.resolve({
        user: { id: 'verified-user', email: 'current@example.test' },
        jwt: 'verified.jwt',
      }),
    execute: () => Promise.resolve({ messageCode: 'PASSWORD_CHANGED' }),
    log: () => {},
    ...overrides,
  };
}

Deno.test('account security accepts POST and returns a stable success envelope', async () => {
  let receivedUserId: string | undefined;
  let receivedEmail: string | undefined;
  const response = await handleAccountSecurityRequest(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({
        action: 'password_changed',
        current_password: 'old',
        new_password: 'ValidPass1',
      }),
    }),
    dependencies({
      execute: (_command, context) => {
        receivedUserId = context.userId;
        receivedEmail = context.email;
        return Promise.resolve({ messageCode: 'PASSWORD_CHANGED' });
      },
    }),
  );

  assert.equal(response.status, 200);
  assert.equal(receivedUserId, 'verified-user');
  assert.equal(receivedEmail, 'current@example.test');
  assert.deepEqual(await response.json(), {
    data: { message_code: 'PASSWORD_CHANGED' },
    error: null,
  });
});

Deno.test('account security failure log keeps context without secrets', async () => {
  const logs: unknown[] = [];
  await handleAccountSecurityRequest(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({
        action: 'password_changed',
        current_password: 'NeverLogThis1',
        new_password: 'NewNeverLog2',
      }),
    }),
    dependencies({
      execute: () => Promise.reject(new Error('ERR_INVALID_CURRENT_PASSWORD')),
      log: (event) => logs.push(event),
    }),
  );

  assert.equal(logs.length, 1);
  const serialized = JSON.stringify(logs[0]);
  assert.match(serialized, /password_changed/);
  assert.match(serialized, /verified-user/);
  assert.equal(serialized.includes('NeverLogThis1'), false);
  assert.equal(serialized.includes('NewNeverLog2'), false);
  assert.equal(serialized.includes('current@example.test'), false);
  assert.equal(serialized.includes('verified.jwt'), false);
});

Deno.test('account security rejects an identity without email', async () => {
  const response = await handleAccountSecurityRequest(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({ action: 'password_recovered', new_password: 'Recovery1' }),
    }),
    dependencies({
      authenticate: () =>
        Promise.resolve({
          user: { id: 'verified-user', email: null },
          jwt: 'verified.jwt',
        }),
    }),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    data: null,
    error: { code: 'ERR_AUTH_EMAIL_REQUIRED' },
  });
});

Deno.test('account security maps invalid current password without provider details', async () => {
  const response = await handleAccountSecurityRequest(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({
        action: 'email_changed',
        current_password: 'wrong',
        new_email: 'new@example.test',
      }),
    }),
    dependencies({
      execute: () => Promise.reject(new Error('ERR_INVALID_CURRENT_PASSWORD')),
    }),
  );

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), {
    data: null,
    error: { code: 'ERR_INVALID_CURRENT_PASSWORD' },
  });
});
