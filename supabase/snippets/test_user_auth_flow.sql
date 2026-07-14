\set ON_ERROR_STOP on

begin;

insert into auth.users (
  id,
  raw_app_meta_data,
  raw_user_meta_data,
  is_sso_user,
  is_anonymous
)
values
  (
    '10000000-0000-4000-8000-000000000001',
    '{}'::jsonb,
    '{"display_name":"Ada Lovelace"}'::jsonb,
    false,
    false
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    '{}'::jsonb,
    '{"display_name":"Grace Hopper"}'::jsonb,
    false,
    false
  );

do $$
begin
  if (select count(*) from public.users) <> 2 then
    raise exception 'profile bootstrap count mismatch';
  end if;
  if not exists (
    select 1 from public.users
    where user_id = '10000000-0000-4000-8000-000000000001'
      and display_name = 'Ada Lovelace'
  ) then
    raise exception 'profile bootstrap payload mismatch';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);

do $$
declare
  v_profile jsonb;
begin
  if (select count(*) from public.users) <> 1 then
    raise exception 'RLS self-read mismatch';
  end if;
  if exists (
    select 1 from public.users
    where user_id = '10000000-0000-4000-8000-000000000002'
  ) then
    raise exception 'RLS exposed another user';
  end if;

  v_profile := public.rpc_get_user_profile();
  if v_profile ->> 'message_code' <> 'USER_PROFILE_READ' then
    raise exception 'profile read RPC mismatch: %', v_profile;
  end if;
end;
$$;

reset role;
set local role service_role;

do $$
declare
  v_result jsonb;
begin
  v_result := public.update_user_profile(
    '10000000-0000-4000-8000-000000000001',
    '{"display_name":"  Ada Byron  "}'::jsonb
  );
  if v_result ->> 'message_code' <> 'USER_PROFILE_UPDATED'
    or v_result -> 'data' ->> 'display_name' <> 'Ada Byron'
  then
    raise exception 'profile update RPC mismatch: %', v_result;
  end if;

  v_result := public.update_user_profile(
    '10000000-0000-4000-8000-000000000001',
    '{"display_name":"A"}'::jsonb
  );
  if v_result ->> 'message_code' <> 'ERR_DISPLAY_NAME_INVALID' then
    raise exception 'invalid profile update was accepted: %', v_result;
  end if;
  if not exists (
    select 1 from public.users
    where user_id = '10000000-0000-4000-8000-000000000001'
      and display_name = 'Ada Byron'
  ) then
    raise exception 'invalid update mutated the profile';
  end if;
end;
$$;

reset role;
delete from auth.users
where id = '10000000-0000-4000-8000-000000000001';

do $$
begin
  if exists (
    select 1 from public.users
    where user_id = '10000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'profile did not cascade after Auth deletion';
  end if;
end;
$$;

rollback;
