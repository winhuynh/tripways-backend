-- Function: public.consume_auth_command_attempt
-- Feature: User authentication
-- Purpose: Atomically consume one fixed-window quota for a hashed rate-limit subject.
-- Responsibilities: Validate bounded inputs, increment a counter, prune stale rows, and report quota.
-- Notes: Execution is restricted to service_role and the function runs with invoker privileges.

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
  -- STEP 01: Reject malformed or unbounded subjects before touching counter state.
  if p_subject_hash is null or p_subject_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'ERR_RATE_LIMIT_SUBJECT_INVALID';
  end if;
  if p_action not in ('password_changed', 'password_recovered', 'email_changed', 'delete_account') then
    raise exception using errcode = '22023', message = 'ERR_RATE_LIMIT_ACTION_INVALID';
  end if;

  v_window_started_at := date_trunc('minute', v_now)
    - ((extract(minute from v_now)::integer % 5) * interval '1 minute');

  -- STEP 02: Consume the fixed-window quota atomically across concurrent requests.
  insert into private.auth_command_attempts (
    subject_hash,
    action,
    window_started_at,
    attempt_count,
    updated_at
  )
  values (p_subject_hash, p_action, v_window_started_at, 1, v_now)
  on conflict (subject_hash, action, window_started_at)
  do update set
    attempt_count = private.auth_command_attempts.attempt_count + 1,
    updated_at = excluded.updated_at
  returning attempt_count into v_attempt_count;

  -- STEP 03: Bound operational state without a separate cleanup worker at MVP scale.
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
