-- ============================================================================
-- Function: public.rpc_get_user_profile
-- Feature: User profile
-- Purpose: Return the current authenticated user's minimal application profile.
-- Responsibilities: Derive caller identity, enforce profile existence,
--   and return a stable envelope.
-- Notes: The internal user UUID is intentionally excluded from the response.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_user_profile()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Auth
  ------------------------------------------------------------------
  v_user_id UUID := auth.uid();

  ------------------------------------------------------------------
  -- Result
  ------------------------------------------------------------------
  v_profile public.users%ROWTYPE;
BEGIN
  -- STEP 01: Reject calls without an authenticated database identity.
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'data', NULL,
      'error', jsonb_build_object('code', 'ERR_UNAUTHORIZED'),
      'message_code', 'ERR_UNAUTHORIZED'
    );
  END IF;

  -- STEP 02: Read the caller-owned row through RLS.
  SELECT *
  INTO v_profile
  FROM public.users
  WHERE user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'data', NULL,
      'error', jsonb_build_object('code', 'ERR_USER_PROFILE_NOT_FOUND'),
      'message_code', 'ERR_USER_PROFILE_NOT_FOUND'
    );
  END IF;

  RETURN jsonb_build_object(
    'status', 'success',
    'data', jsonb_build_object(
      'display_name', v_profile.display_name,
      'account_status', v_profile.account_status,
      'created_at', v_profile.created_at,
      'updated_at', v_profile.updated_at
    ),
    'error', NULL,
    'message_code', 'USER_PROFILE_READ'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_user_profile() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.rpc_get_user_profile() TO authenticated, service_role;
