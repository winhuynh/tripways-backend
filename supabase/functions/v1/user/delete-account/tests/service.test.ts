import assert from 'node:assert/strict';
import { type DeleteAccountDependencies, executeDeleteAccount } from '../service.ts';

function dependencies(events: string[]): DeleteAccountDependencies {
  return {
    enforceRateLimit: () => {
      events.push('rate:delete_account');
      return Promise.resolve();
    },
    reauthenticate: (_email, password) => {
      events.push(`reauth:${password}`);
      return Promise.resolve();
    },
    deleteAuthUser: (userId) => {
      events.push(`delete:${userId}`);
      return Promise.resolve('deleted');
    },
  };
}

Deno.test('delete command uses only the verified identity after reauthentication', async () => {
  const events: string[] = [];
  const result = await executeDeleteAccount(
    { currentPassword: 'old' },
    { userId: 'verified-user', email: 'current@example.test' },
    dependencies(events),
  );

  assert.deepEqual(events, [
    'rate:delete_account',
    'reauth:old',
    'delete:verified-user',
  ]);
  assert.equal(result.messageCode, 'ACCOUNT_DELETED');
});

Deno.test('invalid current password stops deletion', async () => {
  const events: string[] = [];
  const deps = dependencies(events);
  deps.reauthenticate = () => Promise.reject(new Error('ERR_INVALID_CURRENT_PASSWORD'));

  await assert.rejects(
    () =>
      executeDeleteAccount(
        { currentPassword: 'wrong' },
        { userId: 'verified-user', email: 'current@example.test' },
        deps,
      ),
    /ERR_INVALID_CURRENT_PASSWORD/,
  );
  assert.deepEqual(events, ['rate:delete_account']);
});

Deno.test('already deleted Auth user returns idempotent success', async () => {
  const events: string[] = [];
  const deps = dependencies(events);
  deps.deleteAuthUser = () => Promise.resolve('not_found');

  const result = await executeDeleteAccount(
    { currentPassword: 'old' },
    { userId: 'verified-user', email: 'current@example.test' },
    deps,
  );

  assert.equal(result.messageCode, 'ACCOUNT_DELETED');
});
