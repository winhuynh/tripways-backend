import assert from 'node:assert/strict';
import { type AccountSecurityDependencies, executeAccountSecurity } from '../service.ts';

function dependencies(events: string[]): AccountSecurityDependencies {
  return {
    enforceRateLimit: (action) => {
      events.push(`rate:${action}`);
      return Promise.resolve();
    },
    reauthenticate: (_email, password) => {
      events.push(`reauth:${password}`);
      return Promise.resolve();
    },
    updatePassword: (_jwt, password, currentPassword) => {
      events.push(`password:${password}:${currentPassword ?? 'recovery'}`);
      return Promise.resolve();
    },
    updateEmail: (_jwt, email, currentPassword) => {
      events.push(`email:${email}:${currentPassword}`);
      return Promise.resolve();
    },
    revokeOtherSessions: () => {
      events.push('revoke:others');
      return Promise.resolve();
    },
  };
}

const context = { email: 'current@example.test', jwt: 'verified.jwt' };

Deno.test('password change reauthenticates before mutation and revocation', async () => {
  const events: string[] = [];
  const result = await executeAccountSecurity(
    { action: 'password_changed', currentPassword: 'old', newPassword: 'ValidPass1' },
    context,
    dependencies(events),
  );

  assert.deepEqual(events, [
    'rate:password_changed',
    'reauth:old',
    'password:ValidPass1:old',
    'revoke:others',
  ]);
  assert.equal(result.messageCode, 'PASSWORD_CHANGED');
});

Deno.test('password recovery updates without current-password reauthentication', async () => {
  const events: string[] = [];
  const result = await executeAccountSecurity(
    { action: 'password_recovered', newPassword: 'Recovery1' },
    context,
    dependencies(events),
  );

  assert.deepEqual(events, [
    'rate:password_recovered',
    'password:Recovery1:recovery',
    'revoke:others',
  ]);
  assert.equal(result.messageCode, 'PASSWORD_RECOVERED');
});

Deno.test('email change reauthenticates before requesting change', async () => {
  const events: string[] = [];
  const result = await executeAccountSecurity(
    { action: 'email_changed', currentPassword: 'old', newEmail: 'new@example.test' },
    context,
    dependencies(events),
  );

  assert.deepEqual(events, [
    'rate:email_changed',
    'reauth:old',
    'email:new@example.test:old',
    'revoke:others',
  ]);
  assert.equal(result.messageCode, 'EMAIL_CHANGE_REQUESTED');
});

Deno.test('failed reauthentication stops credential side effects', async () => {
  const events: string[] = [];
  const deps = dependencies(events);
  deps.reauthenticate = () => {
    events.push('reauth:failed');
    return Promise.reject(new Error('ERR_INVALID_CURRENT_PASSWORD'));
  };

  await assert.rejects(
    () =>
      executeAccountSecurity(
        { action: 'password_changed', currentPassword: 'wrong', newPassword: 'ValidPass1' },
        context,
        deps,
      ),
    /ERR_INVALID_CURRENT_PASSWORD/,
  );
  assert.deepEqual(events, ['rate:password_changed', 'reauth:failed']);
});
