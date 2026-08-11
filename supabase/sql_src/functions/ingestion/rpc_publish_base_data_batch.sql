-- ============================================================================
-- Function: public.rpc_publish_base_data_batch
-- Purpose: Provide a service-role-only PostgREST transport to private publication.
-- Responsibilities:
--   - Forward the bounded canonical batch to the private transactional function.
--   - Keep the exposed wrapper security-invoker and unavailable to public clients.
-- Notes:
--   - Domain validation and mutation remain in private.publish_base_data_batch.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_publish_base_data_batch(
  p_source_code       TEXT,
  p_idempotency_key   TEXT,
  p_checksum          TEXT,
  p_provider_version  TEXT,
  p_source_time       TIMESTAMPTZ,
  p_records           JSONB,
  p_import_metadata   JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
SET search_path = ''
AS $$
  SELECT private.publish_base_data_batch(
    p_source_code,
    p_idempotency_key,
    p_checksum,
    p_provider_version,
    p_source_time,
    p_records,
    p_import_metadata
  );
$$;

REVOKE ALL ON FUNCTION public.rpc_publish_base_data_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB,
  JSONB
) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_publish_base_data_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB,
  JSONB
) TO service_role;
