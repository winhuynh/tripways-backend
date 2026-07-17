\set ON_ERROR_STOP on

BEGIN;

INSERT INTO auth.users (
  id,
  raw_app_meta_data,
  raw_user_meta_data,
  is_sso_user,
  is_anonymous
)
VALUES
  (
    '10000000-0000-4000-8000-000000000001',
    '{}'::JSONB,
    '{"display_name":"Ada Lovelace"}'::JSONB,
    FALSE,
    FALSE
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    '{}'::JSONB,
    '{"display_name":"Grace Hopper"}'::JSONB,
    FALSE,
    FALSE
  );

DO $$
BEGIN
  IF (SELECT count(*) FROM public.users) <> 2 THEN
    RAISE EXCEPTION 'profile bootstrap count mismatch';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE user_id = '10000000-0000-4000-8000-000000000001'
      AND display_name = 'Ada Lovelace'
  ) THEN
    RAISE EXCEPTION 'profile bootstrap payload mismatch';
  END IF;
END;
$$;

SET LOCAL role authenticated;
SELECT set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  TRUE
);

DO $$
DECLARE
  v_profile JSONB;
BEGIN
  IF (SELECT count(*) FROM public.users) <> 1 THEN
    RAISE EXCEPTION 'RLS self-read mismatch';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE user_id = '10000000-0000-4000-8000-000000000002'
  ) THEN
    RAISE EXCEPTION 'RLS exposed another user';
  END IF;

  v_profile := public.rpc_get_user_profile();
  IF v_profile ->> 'message_code' <> 'USER_PROFILE_READ' THEN
    RAISE EXCEPTION 'profile read RPC mismatch: %', v_profile;
  END IF;
END;
$$;

RESET ROLE;
SET LOCAL role service_role;

DO $$
DECLARE
  v_result JSONB;
BEGIN
  v_result := public.update_user_profile(
    '10000000-0000-4000-8000-000000000001',
    '{"display_name":"  Ada Byron  "}'::JSONB
  );
  IF v_result ->> 'message_code' <> 'USER_PROFILE_UPDATED'
    OR v_result -> 'data' ->> 'display_name' <> 'Ada Byron'
  THEN
    RAISE EXCEPTION 'profile update RPC mismatch: %', v_result;
  END IF;

  v_result := public.update_user_profile(
    '10000000-0000-4000-8000-000000000001',
    '{"display_name":"A"}'::JSONB
  );
  IF v_result ->> 'message_code' <> 'ERR_DISPLAY_NAME_INVALID' THEN
    RAISE EXCEPTION 'invalid profile update was accepted: %', v_result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE user_id = '10000000-0000-4000-8000-000000000001'
      AND display_name = 'Ada Byron'
  ) THEN
    RAISE EXCEPTION 'invalid update mutated the profile';
  END IF;
END;
$$;

RESET ROLE;
DELETE FROM auth.users
WHERE id = '10000000-0000-4000-8000-000000000001';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE user_id = '10000000-0000-4000-8000-000000000001'
  ) THEN
    RAISE EXCEPTION 'profile did not cascade after Auth deletion';
  END IF;
END;
$$;

ROLLBACK;
