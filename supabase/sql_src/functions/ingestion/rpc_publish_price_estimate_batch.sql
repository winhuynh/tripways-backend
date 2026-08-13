-- ============================================================================
-- Function: public.rpc_publish_price_estimate_batch
-- Purpose: Expose the price-estimate publisher to the trusted ingestion service.
-- Responsibilities: Forward a validated service-role request to the admin publisher.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_publish_price_estimate_batch(
  p_source_code             TEXT,
  p_idempotency_key         TEXT,
  p_checksum                TEXT,
  p_provider_version        TEXT,
  p_source_time             TIMESTAMPTZ,
  p_observations            JSONB,
  p_publication_source_type TEXT
)
RETURNS JSONB
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT admin.publish_price_estimate_batch(
    p_source_code,
    p_idempotency_key,
    p_checksum,
    p_provider_version,
    p_source_time,
    p_observations,
    p_publication_source_type
  );
$$;

REVOKE ALL ON FUNCTION public.rpc_publish_price_estimate_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB,
  TEXT
)
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.rpc_publish_price_estimate_batch(
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  TIMESTAMPTZ,
  JSONB,
  TEXT
)
TO service_role;
