-- Function: public.rpc_get_user_profile
-- Feature: User profile
-- Purpose: Return the current authenticated user's minimal application profile.
-- Responsibilities: Derive caller identity, enforce profile existence, and return a stable envelope.
-- Notes: The internal user UUID is intentionally excluded from the response.

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
  -- STEP 01: Reject calls without an authenticated database identity.
  if v_user_id is null then
    return jsonb_build_object(
      'status', 'error',
      'data', null,
      'error', jsonb_build_object('code', 'ERR_UNAUTHORIZED'),
      'message_code', 'ERR_UNAUTHORIZED'
    );
  end if;

  -- STEP 02: Read the caller-owned row through RLS.
  select *
  into v_profile
  from public.users
  where user_id = v_user_id;

  if not found then
    return jsonb_build_object(
      'status', 'error',
      'data', null,
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
