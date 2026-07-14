import assert from 'node:assert/strict';

const config = await Deno.readTextFile(
  new URL('../../../../config.toml', import.meta.url),
);

async function readSource(relativePath: string): Promise<string> {
  try {
    return await Deno.readTextFile(new URL(relativePath, import.meta.url));
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return '';
    throw error;
  }
}

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

Deno.test('users table is minimal, constrained, and self-readable only', async () => {
  const sql = await readSource('../../../../sql_src/schema/public/users.sql');

  assert.ok(sql.includes('references auth.users (id) on delete cascade'));
  assert.ok(sql.includes('users_display_name_length_check'));
  assert.ok(sql.includes('users_account_status_check'));
  assert.ok(sql.includes('alter table public.users enable row level security'));
  assert.ok(sql.includes('revoke all on table public.users from anon, authenticated'));
  assert.ok(sql.includes('create policy users_self_read'));
  assert.ok(sql.includes('user_id = (select auth.uid())'));
  assert.equal(sql.includes('for insert to authenticated'), false);
  assert.equal(sql.includes('for update to authenticated'), false);
  assert.equal(sql.includes('for delete to authenticated'), false);
});

Deno.test('auth bootstrap validates display name in a private definer function', async () => {
  const sql = await readSource(
    '../../../../sql_src/functions/user/handle_new_auth_user.sql',
  );

  assert.ok(sql.includes('private.handle_new_auth_user()'));
  assert.ok(sql.includes('security definer'));
  assert.ok(sql.includes("set search_path = ''"));
  assert.ok(sql.includes("new.raw_user_meta_data ->> 'display_name'"));
  assert.ok(sql.includes('ERR_DISPLAY_NAME_INVALID'));
  assert.ok(sql.includes('char_length(v_display_name) between 2 and 80'));
  assert.equal(sql.includes('public.handle_new_auth_user()'), false);
});

Deno.test('auth bootstrap trigger runs only after user creation', async () => {
  const sql = await readSource(
    '../../../../sql_src/triggers/user/trg_handle_new_auth_user.sql',
  );

  assert.ok(sql.includes('after insert on auth.users'));
  assert.ok(sql.includes('execute function private.handle_new_auth_user()'));
  assert.equal(sql.includes('after insert or update'), false);
});

Deno.test('profile read RPC derives identity and never exposes the user UUID', async () => {
  const sql = await readSource(
    '../../../../sql_src/functions/user/rpc_get_user_profile.sql',
  );

  assert.ok(sql.includes('public.rpc_get_user_profile()'));
  assert.ok(sql.includes('security invoker'));
  assert.ok(sql.includes('auth.uid()'));
  assert.ok(sql.includes('ERR_UNAUTHORIZED'));
  assert.ok(sql.includes('ERR_USER_PROFILE_NOT_FOUND'));
  assert.ok(sql.includes('USER_PROFILE_READ'));
  assert.equal(sql.includes("'user_id'"), false);
  assert.ok(sql.includes('to authenticated, service_role'));
});

Deno.test('profile mutation is invoker-only and executable only by service role', async () => {
  const sql = await readSource(
    '../../../../sql_src/functions/user/update_user_profile.sql',
  );

  assert.ok(sql.includes('public.update_user_profile(p_user_id uuid, p_input jsonb)'));
  assert.ok(sql.includes('security invoker'));
  assert.equal(sql.includes('security definer'), false);
  assert.ok(sql.includes("set search_path = ''"));
  assert.ok(sql.includes('ERR_DISPLAY_NAME_INVALID'));
  assert.ok(sql.includes('USER_PROFILE_UPDATED'));
  assert.ok(sql.includes('where user_id = p_user_id'));
  assert.ok(sql.includes('update public.users'));
  assert.equal(sql.includes("'user_id'"), false);
  assert.ok(
    sql.includes(
      'revoke all on function public.update_user_profile(uuid, jsonb) from public, anon, authenticated',
    ),
  );
  assert.ok(
    sql.includes(
      'grant execute on function public.update_user_profile(uuid, jsonb) to service_role',
    ),
  );
});

Deno.test('auth command attempts store only bounded hashed subjects in private', async () => {
  const sql = await readSource(
    '../../../../sql_src/schema/private/auth_command_attempts.sql',
  );

  assert.ok(sql.includes('create table private.auth_command_attempts'));
  assert.ok(sql.includes('subject_hash text not null'));
  assert.ok(sql.includes('attempt_count integer not null'));
  assert.ok(sql.includes('auth_command_attempts_count_check'));
  assert.ok(sql.includes('revoke all on table private.auth_command_attempts from public, anon, authenticated'));
  assert.equal(sql.includes('ip_address'), false);
  assert.equal(sql.includes('user_id'), false);
});

Deno.test('rate limit RPC is invoker-only and callable only by service role', async () => {
  const sql = await readSource(
    '../../../../sql_src/functions/user/consume_auth_command_attempt.sql',
  );

  assert.ok(sql.includes('public.consume_auth_command_attempt'));
  assert.ok(sql.includes('security invoker'));
  assert.equal(sql.includes('security definer'), false);
  assert.ok(sql.includes("interval '5 minutes'"));
  assert.ok(sql.includes('v_limit constant integer := 5'));
  assert.ok(sql.includes("interval '24 hours'"));
  assert.ok(sql.includes('on conflict (subject_hash, action, window_started_at)'));
  assert.ok(sql.includes('to service_role'));
  assert.equal(sql.includes('to authenticated'), false);
});
