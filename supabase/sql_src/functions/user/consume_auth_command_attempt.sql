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
    'delete_account',
    'flight_route_cache_refresh'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_RATE_LIMIT_ACTION_INVALID';
  END IF;

  v_window_started_at := date_trunc('minute', v_now)
    - ((extract(MINUTE FROM v_now)::INTEGER % 5) * INTERVAL '1 minute');

  -- STEP 02: Consume the fixed-window quota atomically across concurrent requests.
  INSERT INTO admin.auth_command_attempts (
    subject_hash,
    action,
    window_started_at,
    attempt_count,
    updated_at
  )
  VALUES (p_subject_hash, p_action, v_window_started_at, 1, v_now)
  ON CONFLICT (subject_hash, action, window_started_at)
  DO UPDATE SET
    attempt_count = admin.auth_command_attempts.attempt_count + 1,
    updated_at = EXCLUDED.updated_at
  RETURNING attempt_count INTO v_attempt_count;

  -- STEP 03: Bound operational state without a separate cleanup worker at MVP scale.
  DELETE FROM admin.auth_command_attempts
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
