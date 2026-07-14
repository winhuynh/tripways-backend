import assert from 'node:assert/strict';
import { parseAccountSecurityRequest } from '../request.ts';

Deno.test('password change preserves opaque passwords exactly', () => {
  const parsed = parseAccountSecurityRequest({
    action: 'password_changed',
    current_password: ' current pass ',
    new_password: ' ValidPass1 ',
  });

  assert.deepEqual(parsed, {
    action: 'password_changed',
    currentPassword: ' current pass ',
    newPassword: ' ValidPass1 ',
  });
});

Deno.test('password recovery requires a policy-compliant new password', () => {
  assert.throws(
    () => parseAccountSecurityRequest({ action: 'password_recovered', new_password: 'weak' }),
    /ERR_PASSWORD_INVALID/,
  );
  assert.deepEqual(
    parseAccountSecurityRequest({ action: 'password_recovered', new_password: 'Recovery1' }),
    { action: 'password_recovered', newPassword: 'Recovery1' },
  );
});

Deno.test('email change trims email but preserves current password', () => {
  assert.deepEqual(
    parseAccountSecurityRequest({
      action: 'email_changed',
      current_password: ' old pass ',
      new_email: '  New.User@example.com ',
    }),
    {
      action: 'email_changed',
      currentPassword: ' old pass ',
      newEmail: 'New.User@example.com',
    },
  );
});

Deno.test('account security rejects malformed email and unknown fields', () => {
  assert.throws(
    () =>
      parseAccountSecurityRequest({
        action: 'email_changed',
        current_password: 'old',
        new_email: 'not-an-email',
      }),
    /ERR_EMAIL_INVALID/,
  );
  assert.throws(
    () =>
      parseAccountSecurityRequest({
        action: 'password_recovered',
        new_password: 'Recovery1',
        user_id: 'other',
      }),
    /ERR_ACCOUNT_SECURITY_REQUEST_INVALID/,
  );
});
