-- ============================================================================
-- Function: private.build_rpc_error
-- Feature: Shared RPC contract
-- Purpose: Build the stable error envelope returned by public read RPCs.
-- Responsibilities: Preserve caller-selected empty data shape, metadata, code, and message.
-- Notes: The helper is internal and executable only by the service-role RPC caller.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.build_rpc_error(
  p_data JSONB,
  p_code TEXT,
  p_message TEXT
)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'data', p_data,
    'meta', '{}'::JSONB,
    'error', jsonb_build_object(
      'code', p_code,
      'message', p_message
    )
  );
$$;

REVOKE ALL ON FUNCTION private.build_rpc_error(JSONB, TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.build_rpc_error(JSONB, TEXT, TEXT) TO service_role;
