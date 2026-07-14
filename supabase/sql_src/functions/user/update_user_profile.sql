-- Function: public.update_user_profile
-- Feature: User profile
-- Purpose: Update a verified Edge caller's display name through a service-role-only RPC.
-- Responsibilities: Validate identity and input, mutate one profile, and return a stable envelope.
-- Notes: p_user_id must come from a JWT verified by the calling Edge Function.

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
  -- STEP 01: Validate the server-injected identity and request shape.
  if p_user_id is null then
    return jsonb_build_object(
      'status', 'error',
      'data', null,
      'error', jsonb_build_object('code', 'ERR_UNAUTHORIZED'),
      'message_code', 'ERR_UNAUTHORIZED'
    );
  end if;

  if jsonb_typeof(p_input) <> 'object'
    or jsonb_typeof(p_input -> 'display_name') <> 'string'
  then
    return jsonb_build_object(
      'status', 'error',
      'data', null,
      'error', jsonb_build_object('code', 'ERR_DISPLAY_NAME_INVALID'),
      'message_code', 'ERR_DISPLAY_NAME_INVALID'
    );
  end if;

  v_display_name := btrim(p_input ->> 'display_name');
  if not (char_length(v_display_name) between 2 and 80) then
    return jsonb_build_object(
      'status', 'error',
      'data', null,
      'error', jsonb_build_object('code', 'ERR_DISPLAY_NAME_INVALID'),
      'message_code', 'ERR_DISPLAY_NAME_INVALID'
    );
  end if;

  -- STEP 02: Mutate exactly the profile selected by verified Edge identity.
  update public.users
  set
    display_name = v_display_name,
    updated_at = now()
  where user_id = p_user_id
  returning * into v_profile;

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
    'message_code', 'USER_PROFILE_UPDATED'
  );
end;
$$;

revoke all on function public.update_user_profile(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.update_user_profile(uuid, jsonb) to service_role;
