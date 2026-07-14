import assert from 'node:assert/strict';
import { parseProfilePatch } from '../request.ts';

Deno.test('profile patch trims and accepts a valid display name', () => {
  assert.deepEqual(parseProfilePatch({ display_name: '  Ada Lovelace  ' }), {
    displayName: 'Ada Lovelace',
  });
});

Deno.test('profile patch rejects invalid names and unknown fields', () => {
  assert.throws(() => parseProfilePatch({ display_name: ' A ' }), /ERR_DISPLAY_NAME_INVALID/);
  assert.throws(
    () => parseProfilePatch({ display_name: 'A'.repeat(81) }),
    /ERR_DISPLAY_NAME_INVALID/,
  );
  assert.throws(
    () => parseProfilePatch({ display_name: 'Ada', user_id: 'other' }),
    /ERR_PROFILE_REQUEST_INVALID/,
  );
});
