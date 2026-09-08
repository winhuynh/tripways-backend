-- ============================================================================
-- Function: admin.purge_expired_direct_flight_routes
-- Purpose: Permanently delete cached direct flight routes older than the allowed retention period (ToS Article 5.5).
-- Responsibilities:
--   - Remove expired routes for a specified data source.
--   - Return count of permanently deleted records.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.purge_expired_direct_flight_routes(
  p_source_code TEXT,
  p_retention_interval INTERVAL DEFAULT '7 days'::INTERVAL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_source_id UUID;
  v_deleted_count INTEGER := 0;
BEGIN
  IF p_source_code IS NULL OR pg_catalog.btrim(p_source_code) = '' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_INVALID_SOURCE_CODE';
  END IF;

  SELECT id INTO v_source_id
  FROM admin.data_sources
  WHERE code = p_source_code;

  IF v_source_id IS NOT NULL THEN
    DELETE FROM public.direct_flight_routes
    WHERE source_id = v_source_id
      AND last_synced_at < (pg_catalog.now() - p_retention_interval);

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'status', 'success',
    'source_code', p_source_code,
    'deleted_count', v_deleted_count
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.purge_expired_direct_flight_routes(TEXT, INTERVAL)
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION admin.purge_expired_direct_flight_routes(TEXT, INTERVAL) TO service_role;
