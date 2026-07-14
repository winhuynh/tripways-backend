import assert from 'node:assert/strict';
import { parseDeleteAccountRequest } from '../request.ts';

Deno.test('delete request preserves the current password exactly', () => {
  assert.deepEqual(parseDeleteAccountRequest({ current_password: ' current pass ' }), {
    currentPassword: ' current pass ',
  });
});

Deno.test('delete request rejects missing password and unknown fields', () => {
  assert.throws(() => parseDeleteAccountRequest({}), /ERR_CURRENT_PASSWORD_REQUIRED/);
  assert.throws(
    () => parseDeleteAccountRequest({ current_password: 'pass', user_id: 'other' }),
    /ERR_DELETE_ACCOUNT_REQUEST_INVALID/,
  );
});
