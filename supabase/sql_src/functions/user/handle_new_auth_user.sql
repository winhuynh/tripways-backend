-- Function: private.handle_new_auth_user
-- Feature: User authentication
-- Purpose: Bootstrap a validated application profile after Auth creates an identity.
-- Responsibilities: Normalize display name, enforce its contract, and insert one profile row.
-- Notes: Signup metadata is input only and is never used for authorization.

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_display_name text := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
begin
  -- STEP 01: Reject incomplete signup metadata before creating application state.
  if not (char_length(v_display_name) between 2 and 80) then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_DISPLAY_NAME_INVALID';
  end if;

  -- STEP 02: Link the validated profile to the authoritative Auth identity.
  insert into public.users (user_id, display_name)
  values (new.id, v_display_name);

  return new;
end;
$$;

revoke all on function private.handle_new_auth_user() from public, anon, authenticated;
