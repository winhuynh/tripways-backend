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

function includesSql(sql: string, fragment: string): boolean {
  const normalize = (value: string) => value.replace(/\s+/g, ' ').trim().toLowerCase();
  return normalize(sql).includes(normalize(fragment));
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

Deno.test('user auth edge functions enable the local edge runtime', () => {
  const edgeRuntime = config.match(/\[edge_runtime\]\n([\s\S]*?)(?=\n\[|$)/)?.[1] ?? '';
  assert.ok(edgeRuntime.includes('enabled = true'));
  assert.ok(config.includes('[functions.user-profile]'));
  assert.ok(config.includes('[functions.user-account-security]'));
  assert.ok(config.includes('[functions.user-delete-account]'));
});

Deno.test('users table is minimal, constrained, and self-readable only', async () => {
  const sql = await readSource('../../../../sql_src/schema/user/users.sql');

  assert.ok(includesSql(sql, 'references auth.users (id) on delete cascade'));
  assert.ok(includesSql(sql, 'users_display_name_length_check'));
  assert.ok(includesSql(sql, 'users_account_status_check'));
  assert.ok(includesSql(sql, 'alter table public.users enable row level security'));
  assert.ok(includesSql(sql, 'revoke all on table public.users from anon, authenticated'));
  assert.ok(includesSql(sql, 'create policy users_self_read'));
  assert.ok(includesSql(sql, 'user_id = (select auth.uid())'));
  assert.equal(includesSql(sql, 'for insert to authenticated'), false);
  assert.equal(includesSql(sql, 'for update to authenticated'), false);
  assert.equal(includesSql(sql, 'for delete to authenticated'), false);
});

Deno.test('auth bootstrap validates display name in a private definer function', async () => {
  const sql = await readSource(
    '../../../../sql_src/functions/user/handle_new_auth_user.sql',
  );

  assert.ok(includesSql(sql, 'private.handle_new_auth_user()'));
  assert.ok(includesSql(sql, 'security definer'));
  assert.ok(includesSql(sql, "set search_path = ''"));
  assert.ok(includesSql(sql, "new.raw_user_meta_data ->> 'display_name'"));
  assert.ok(includesSql(sql, 'ERR_DISPLAY_NAME_INVALID'));
  assert.ok(includesSql(sql, 'char_length(v_display_name) between 2 and 80'));
  assert.equal(includesSql(sql, 'public.handle_new_auth_user()'), false);
});

Deno.test('auth bootstrap trigger runs only after user creation', async () => {
  const sql = await readSource(
    '../../../../sql_src/triggers/user/trg_handle_new_auth_user.sql',
  );

  assert.ok(includesSql(sql, 'after insert on auth.users'));
  assert.ok(includesSql(sql, 'execute function private.handle_new_auth_user()'));
  assert.equal(includesSql(sql, 'after insert or update'), false);
});

Deno.test('profile read RPC derives identity and never exposes the user UUID', async () => {
  const sql = await readSource(
    '../../../../sql_src/functions/user/rpc_get_user_profile.sql',
  );

  assert.ok(includesSql(sql, 'public.rpc_get_user_profile()'));
  assert.ok(includesSql(sql, 'security invoker'));
  assert.ok(includesSql(sql, 'auth.uid()'));
  assert.ok(includesSql(sql, 'ERR_UNAUTHORIZED'));
  assert.ok(includesSql(sql, 'ERR_USER_PROFILE_NOT_FOUND'));
  assert.ok(includesSql(sql, 'USER_PROFILE_READ'));
  assert.equal(includesSql(sql, "'user_id'"), false);
  assert.ok(includesSql(sql, 'to authenticated, service_role'));
});

Deno.test('profile mutation is invoker-only and executable only by service role', async () => {
  const sql = await readSource(
    '../../../../sql_src/functions/user/update_user_profile.sql',
  );

  assert.ok(includesSql(sql, 'public.update_user_profile(p_user_id uuid, p_input jsonb)'));
  assert.ok(includesSql(sql, 'security invoker'));
  assert.equal(includesSql(sql, 'security definer'), false);
  assert.ok(includesSql(sql, "set search_path = ''"));
  assert.ok(includesSql(sql, 'ERR_DISPLAY_NAME_INVALID'));
  assert.ok(includesSql(sql, 'USER_PROFILE_UPDATED'));
  assert.ok(includesSql(sql, 'where user_id = p_user_id'));
  assert.ok(includesSql(sql, 'update public.users'));
  assert.equal(includesSql(sql, "'user_id'"), false);
  assert.ok(
    includesSql(
      sql,
      'revoke all on function public.update_user_profile(uuid, jsonb) from public, anon, authenticated',
    ),
  );
  assert.ok(
    includesSql(
      sql,
      'grant execute on function public.update_user_profile(uuid, jsonb) to service_role',
    ),
  );
});

Deno.test('auth command attempts store only bounded hashed subjects in private', async () => {
  const sql = await readSource(
    '../../../../sql_src/schema/user/auth_command_attempts.sql',
  );

  assert.ok(includesSql(sql, 'create table private.auth_command_attempts'));
  assert.ok(includesSql(sql, 'subject_hash text not null'));
  assert.ok(includesSql(sql, 'attempt_count integer not null'));
  assert.ok(includesSql(sql, 'auth_command_attempts_count_check'));
  assert.ok(
    includesSql(
      sql,
      'revoke all on table private.auth_command_attempts from public, anon, authenticated',
    ),
  );
  assert.equal(includesSql(sql, 'ip_address'), false);
  assert.equal(includesSql(sql, 'user_id'), false);
});

Deno.test('rate limit RPC is invoker-only and callable only by service role', async () => {
  const sql = await readSource(
    '../../../../sql_src/functions/user/consume_auth_command_attempt.sql',
  );

  assert.ok(includesSql(sql, 'public.consume_auth_command_attempt'));
  assert.ok(includesSql(sql, 'security invoker'));
  assert.equal(includesSql(sql, 'security definer'), false);
  assert.ok(includesSql(sql, "interval '5 minutes'"));
  assert.ok(includesSql(sql, 'v_limit constant integer := 5'));
  assert.ok(includesSql(sql, "interval '24 hours'"));
  assert.ok(includesSql(sql, 'on conflict (subject_hash, action, window_started_at)'));
  assert.ok(includesSql(sql, 'to service_role'));
  assert.equal(includesSql(sql, 'to authenticated'), false);
});
