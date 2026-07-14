import assert from 'node:assert/strict';

const config = await Deno.readTextFile(
  new URL('../../../../config.toml', import.meta.url),
);

Deno.test('auth requires confirmed email and disables anonymous users', () => {
  assert.ok(config.includes('enable_signup = true'));
  assert.ok(config.includes('enable_anonymous_sign_ins = false'));
  assert.ok(config.includes('minimum_password_length = 8'));
  assert.ok(config.includes('password_requirements = "lower_upper_letters_digits"'));
  assert.ok(config.includes('enable_confirmations = true'));
  assert.ok(config.includes('secure_password_change = true'));
});

Deno.test('access token lifetime bounds revoked-session exposure', () => {
  assert.ok(config.includes('jwt_expiry = 3600'));
  assert.equal(config.includes('enable_manual_linking = true'), false);
});
