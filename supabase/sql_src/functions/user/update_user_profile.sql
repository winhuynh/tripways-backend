-- ============================================================================
-- Function: public.update_user_profile
-- Feature: User profile
-- Purpose: Update a verified Edge caller's display name through a service-role-only RPC.
-- Responsibilities: Validate identity and input, mutate one profile, and return a stable envelope.
-- Notes: p_user_id must come from a JWT verified by the calling Edge Function.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_user_profile(p_user_id UUID, p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Input
  ------------------------------------------------------------------
  v_display_name TEXT;

  ------------------------------------------------------------------
  -- Result
  ------------------------------------------------------------------
  v_profile public.users%ROWTYPE;
BEGIN
  -- STEP 01: Validate the server-injected identity and request shape.
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'data', NULL,
      'error', jsonb_build_object('code', 'ERR_UNAUTHORIZED'),
      'message_code', 'ERR_UNAUTHORIZED'
    );
  END IF;

  IF jsonb_typeof(p_input) <> 'object'
    OR jsonb_typeof(p_input -> 'display_name') <> 'string'
  THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'data', NULL,
      'error', jsonb_build_object('code', 'ERR_DISPLAY_NAME_INVALID'),
      'message_code', 'ERR_DISPLAY_NAME_INVALID'
    );
  END IF;

  v_display_name := btrim(p_input ->> 'display_name');
  IF NOT (char_length(v_display_name) BETWEEN 2 AND 80) THEN
    RETURN jsonb_build_object(
      'status', 'error',
      'data', NULL,
      'error', jsonb_build_object('code', 'ERR_DISPLAY_NAME_INVALID'),
      'message_code', 'ERR_DISPLAY_NAME_INVALID'
    );
  END IF;

  -- STEP 02: Mutate exactly the profile selected by verified Edge identity.
  UPDATE public.users
  SET
    display_name = v_display_name,
    updated_at = now()
  WHERE user_id = p_user_id
  RETURNING * INTO v_profile;

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
    'message_code', 'USER_PROFILE_UPDATED'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_user_profile(UUID, JSONB) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_profile(UUID, JSONB) TO service_role;
