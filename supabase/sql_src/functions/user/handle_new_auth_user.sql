-- ============================================================================
-- Function: private.handle_new_auth_user
-- Feature: User authentication
-- Purpose: Bootstrap a validated application profile after Auth creates an identity.
-- Responsibilities: Normalize display name, enforce its contract, and insert one profile row.
-- Notes: Signup metadata is input only and is never used for authorization.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_display_name TEXT := btrim(COALESCE(NEW.raw_user_meta_data ->> 'display_name', ''));
BEGIN
  -- STEP 01: Reject incomplete signup metadata before creating application state.
  IF NOT (char_length(v_display_name) BETWEEN 2 AND 80) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'ERR_DISPLAY_NAME_INVALID';
  END IF;

  -- STEP 02: Link the validated profile to the authoritative Auth identity.
  INSERT INTO public.users (user_id, display_name)
  VALUES (NEW.id, v_display_name);

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.handle_new_auth_user() FROM public, anon, authenticated;
