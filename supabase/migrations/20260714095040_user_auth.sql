-- Source: supabase/sql_src/schema/private/auth_command_attempts.sql
create table private.auth_command_attempts (
  subject_hash text not null,
  action text not null,
  window_started_at timestamptz not null,
  attempt_count integer not null,
  updated_at timestamptz not null default now(),
  constraint auth_command_attempts_pkey
    primary key (subject_hash, action, window_started_at),
  constraint auth_command_attempts_subject_hash_check
    check (subject_hash ~ '^[0-9a-f]{64}$'),
  constraint auth_command_attempts_action_check
    check (action in ('password_changed', 'password_recovered', 'email_changed', 'delete_account')),
  constraint auth_command_attempts_count_check
    check (attempt_count > 0)
);

revoke all on table private.auth_command_attempts from public, anon, authenticated;
grant usage on schema private to service_role;
grant select, insert, update, delete on table private.auth_command_attempts to service_role;

-- Source: supabase/sql_src/schema/public/users.sql
create table public.users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  account_status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_display_name_length_check
    check (char_length(display_name) between 2 and 80),
  constraint users_display_name_trimmed_check
    check (display_name = btrim(display_name)),
  constraint users_account_status_check
    check (account_status = 'active')
);

alter table public.users enable row level security;

revoke all on table public.users from anon, authenticated;
grant select on table public.users to authenticated, service_role;
grant insert, update, delete on table public.users to service_role;

create policy users_self_read
on public.users
for select
to authenticated
using (user_id = (select auth.uid()));

-- Source: supabase/sql_src/functions/user/handle_new_auth_user.sql
create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_display_name text := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
begin
  if not (char_length(v_display_name) between 2 and 80) then
    raise exception using errcode = 'P0001', message = 'ERR_DISPLAY_NAME_INVALID';
  end if;

  insert into public.users (user_id, display_name)
  values (new.id, v_display_name);

  return new;
end;
$$;

revoke all on function private.handle_new_auth_user() from public, anon, authenticated;

-- Source: supabase/sql_src/triggers/user/trg_handle_new_auth_user.sql
drop trigger if exists trg_handle_new_auth_user on auth.users;

create trigger trg_handle_new_auth_user
after insert on auth.users
for each row
execute function private.handle_new_auth_user();

-- Source: supabase/sql_src/functions/user/rpc_get_user_profile.sql
create or replace function public.rpc_get_user_profile()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.users%rowtype;
begin
  if v_user_id is null then
    return jsonb_build_object(
      'status', 'error', 'data', null,
      'error', jsonb_build_object('code', 'ERR_UNAUTHORIZED'),
      'message_code', 'ERR_UNAUTHORIZED'
    );
  end if;

  select * into v_profile
  from public.users
  where user_id = v_user_id;

  if not found then
    return jsonb_build_object(
      'status', 'error', 'data', null,
      'error', jsonb_build_object('code', 'ERR_USER_PROFILE_NOT_FOUND'),
      'message_code', 'ERR_USER_PROFILE_NOT_FOUND'
    );
  end if;

  return jsonb_build_object(
    'status', 'success',
    'data', jsonb_build_object(
      'display_name', v_profile.display_name,
      'account_status', v_profile.account_status,
      'created_at', v_profile.created_at,
      'updated_at', v_profile.updated_at
    ),
    'error', null,
    'message_code', 'USER_PROFILE_READ'
  );
end;
$$;

revoke all on function public.rpc_get_user_profile() from public, anon;
grant execute on function public.rpc_get_user_profile() to authenticated, service_role;

-- Source: supabase/sql_src/functions/user/update_user_profile.sql
create or replace function public.update_user_profile(p_user_id uuid, p_input jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_display_name text;
  v_profile public.users%rowtype;
begin
  if p_user_id is null then
    return jsonb_build_object(
      'status', 'error', 'data', null,
      'error', jsonb_build_object('code', 'ERR_UNAUTHORIZED'),
      'message_code', 'ERR_UNAUTHORIZED'
    );
  end if;

  if jsonb_typeof(p_input) <> 'object'
    or jsonb_typeof(p_input -> 'display_name') <> 'string'
  then
    return jsonb_build_object(
      'status', 'error', 'data', null,
      'error', jsonb_build_object('code', 'ERR_DISPLAY_NAME_INVALID'),
      'message_code', 'ERR_DISPLAY_NAME_INVALID'
    );
  end if;

  v_display_name := btrim(p_input ->> 'display_name');
  if not (char_length(v_display_name) between 2 and 80) then
    return jsonb_build_object(
      'status', 'error', 'data', null,
      'error', jsonb_build_object('code', 'ERR_DISPLAY_NAME_INVALID'),
      'message_code', 'ERR_DISPLAY_NAME_INVALID'
    );
  end if;

  update public.users
  set display_name = v_display_name, updated_at = now()
  where user_id = p_user_id
  returning * into v_profile;

  if not found then
    return jsonb_build_object(
      'status', 'error', 'data', null,
      'error', jsonb_build_object('code', 'ERR_USER_PROFILE_NOT_FOUND'),
      'message_code', 'ERR_USER_PROFILE_NOT_FOUND'
    );
  end if;

  return jsonb_build_object(
    'status', 'success',
    'data', jsonb_build_object(
      'display_name', v_profile.display_name,
      'account_status', v_profile.account_status,
      'created_at', v_profile.created_at,
      'updated_at', v_profile.updated_at
    ),
    'error', null,
    'message_code', 'USER_PROFILE_UPDATED'
  );
end;
$$;

revoke all on function public.update_user_profile(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.update_user_profile(uuid, jsonb) to service_role;

-- Source: supabase/sql_src/functions/user/consume_auth_command_attempt.sql
create or replace function public.consume_auth_command_attempt(
  p_subject_hash text,
  p_action text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_limit constant integer := 5;
  v_now timestamptz := now();
  v_window_started_at timestamptz;
  v_attempt_count integer;
begin
  if p_subject_hash is null or p_subject_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'ERR_RATE_LIMIT_SUBJECT_INVALID';
  end if;
  if p_action not in ('password_changed', 'password_recovered', 'email_changed', 'delete_account') then
    raise exception using errcode = '22023', message = 'ERR_RATE_LIMIT_ACTION_INVALID';
  end if;

  v_window_started_at := date_trunc('minute', v_now)
    - ((extract(minute from v_now)::integer % 5) * interval '1 minute');

  insert into private.auth_command_attempts (
    subject_hash, action, window_started_at, attempt_count, updated_at
  )
  values (p_subject_hash, p_action, v_window_started_at, 1, v_now)
  on conflict (subject_hash, action, window_started_at)
  do update set
    attempt_count = private.auth_command_attempts.attempt_count + 1,
    updated_at = excluded.updated_at
  returning attempt_count into v_attempt_count;

  delete from private.auth_command_attempts
  where window_started_at < v_now - interval '24 hours';

  return jsonb_build_object(
    'allowed', v_attempt_count <= v_limit,
    'remaining', greatest(v_limit - v_attempt_count, 0),
    'reset_at', v_window_started_at + interval '5 minutes'
  );
end;
$$;

revoke all on function public.consume_auth_command_attempt(text, text)
from public, anon, authenticated;
grant execute on function public.consume_auth_command_attempt(text, text) to service_role;
