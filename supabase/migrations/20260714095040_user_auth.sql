-- Source: supabase/sql_src/schema/private/auth_command_attempts.sql
-- Table: private.auth_command_attempts
-- Feature: User authentication
-- Purpose: Persist bounded counters for sensitive account-command rate limits.
-- Responsibilities: Store only hashed subjects, actions, fixed windows, and attempt counts.
-- Notes: Raw user IDs and IP addresses are never persisted.

CREATE TABLE private.auth_command_attempts (
  subject_hash       TEXT         NOT NULL,
  action             TEXT         NOT NULL,
  window_started_at  TIMESTAMPTZ  NOT NULL,
  attempt_count      INTEGER      NOT NULL,
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT auth_command_attempts_pkey
    PRIMARY KEY (subject_hash, action, window_started_at),

  CONSTRAINT auth_command_attempts_subject_hash_check
    CHECK (subject_hash ~ '^[0-9a-f]{64}$'),

  CONSTRAINT auth_command_attempts_action_check
    CHECK (action IN ('password_changed', 'password_recovered', 'email_changed', 'delete_account')),

  CONSTRAINT auth_command_attempts_count_check
    CHECK (attempt_count > 0)
);

REVOKE ALL ON TABLE private.auth_command_attempts FROM public, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.auth_command_attempts TO service_role;

-- Source: supabase/sql_src/schema/public/users.sql
-- Table: public.users
-- Feature: User
-- Purpose: Store the minimal application profile for an authenticated identity.
-- Responsibilities: Enforce profile shape, account state, ownership, and lifecycle linkage.
-- Notes: Email and credentials remain authoritative in auth.users.

CREATE TABLE public.users (
  user_id         UUID         PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  display_name    TEXT         NOT NULL,
  account_status  TEXT         NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT users_display_name_length_check
    CHECK (char_length(display_name) BETWEEN 2 AND 80),

  CONSTRAINT users_display_name_trimmed_check
    CHECK (display_name = btrim(display_name)),

  CONSTRAINT users_account_status_check
    CHECK (account_status = 'active')
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.users FROM anon, authenticated;
GRANT SELECT ON TABLE public.users TO authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.users TO service_role;

CREATE POLICY users_self_read
ON public.users
FOR SELECT
TO authenticated
USING (user_id = (SELECT auth.uid()));

-- Source: supabase/sql_src/functions/user/handle_new_auth_user.sql
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

-- Source: supabase/sql_src/triggers/user/trg_handle_new_auth_user.sql
-- ============================================================================
-- Trigger: trg_handle_new_auth_user
-- Feature: User authentication
-- Purpose: Create application profile state after an Auth identity is inserted.
-- Responsibilities: Delegate bootstrap validation and insertion to the private function.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_handle_new_auth_user ON auth.users;

CREATE TRIGGER trg_handle_new_auth_user
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION private.handle_new_auth_user();

-- Source: supabase/sql_src/functions/user/rpc_get_user_profile.sql
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

-- Source: supabase/sql_src/functions/user/update_user_profile.sql
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

-- Source: supabase/sql_src/functions/user/consume_auth_command_attempt.sql
-- ============================================================================
-- Function: public.consume_auth_command_attempt
-- Feature: User authentication
-- Purpose: Atomically consume one fixed-window quota for a hashed rate-limit subject.
-- Responsibilities: Validate bounded inputs, increment a counter, prune stale rows,
--   and report the remaining quota.
-- Notes: Execution is restricted to service_role and the function runs with invoker privileges.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.consume_auth_command_attempt(
  p_subject_hash TEXT,
  p_action TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Configuration
  ------------------------------------------------------------------
  v_limit CONSTANT INTEGER := 5;

  ------------------------------------------------------------------
  -- Window state
  ------------------------------------------------------------------
  v_now TIMESTAMPTZ := now();
  v_window_started_at TIMESTAMPTZ;
  v_attempt_count INTEGER;
BEGIN
  -- STEP 01: Reject malformed or unbounded subjects before touching counter state.
  IF p_subject_hash IS NULL OR p_subject_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_RATE_LIMIT_SUBJECT_INVALID';
  END IF;
  IF p_action NOT IN (
    'password_changed',
    'password_recovered',
    'email_changed',
    'delete_account'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_RATE_LIMIT_ACTION_INVALID';
  END IF;

  v_window_started_at := date_trunc('minute', v_now)
    - ((extract(MINUTE FROM v_now)::INTEGER % 5) * INTERVAL '1 minute');

  -- STEP 02: Consume the fixed-window quota atomically across concurrent requests.
  INSERT INTO private.auth_command_attempts (
    subject_hash,
    action,
    window_started_at,
    attempt_count,
    updated_at
  )
  VALUES (p_subject_hash, p_action, v_window_started_at, 1, v_now)
  ON CONFLICT (subject_hash, action, window_started_at)
  DO UPDATE SET
    attempt_count = private.auth_command_attempts.attempt_count + 1,
    updated_at = EXCLUDED.updated_at
  RETURNING attempt_count INTO v_attempt_count;

  -- STEP 03: Bound operational state without a separate cleanup worker at MVP scale.
  DELETE FROM private.auth_command_attempts
  WHERE window_started_at < v_now - INTERVAL '24 hours';

  RETURN jsonb_build_object(
    'allowed', v_attempt_count <= v_limit,
    'remaining', GREATEST(v_limit - v_attempt_count, 0),
    'reset_at', v_window_started_at + INTERVAL '5 minutes'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.consume_auth_command_attempt(TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_auth_command_attempt(TEXT, TEXT) TO service_role;
