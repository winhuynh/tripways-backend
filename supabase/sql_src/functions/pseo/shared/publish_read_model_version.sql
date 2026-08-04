-- ============================================================================
-- Function: public.publish_read_model_version
-- Purpose: Atomically build and publish one complete shared read-model version.
-- Responsibilities: Refresh route search and all page models before flipping the current marker.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.publish_read_model_version(p_source_type TEXT DEFAULT 'development_fixture')
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SET search_path = ''
AS $$
DECLARE
  v_version_id UUID;
  v_route_count INTEGER;
  v_page_counts JSONB;
BEGIN
  IF p_source_type NOT IN ('production', 'development_fixture') THEN
    RETURN private.build_rpc_error(NULL, 'ERR_INVALID_REQUEST', 'Invalid publication source type.');
  END IF;

  -- STEP 01: Serialize publishers so two candidates cannot race the current marker.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('tripways:read-model-publication', 0)
  );

  INSERT INTO public.publication_versions (source_type)
  VALUES (p_source_type)
  RETURNING id
  INTO v_version_id;

  -- STEP 02: Keep candidate failures in a subtransaction and preserve the current version.
  BEGIN
    v_route_count := private.refresh_route_search_options(v_version_id);
    v_page_counts := private.refresh_page_read_models(v_version_id);

    IF v_route_count = 0
      OR COALESCE((v_page_counts->>'homepage')::INTEGER, 0) = 0
    THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'ERR_PUBLICATION_INCOMPLETE';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      UPDATE public.publication_versions
      SET
        status = 'failed',
        failure_code = CASE
          WHEN SQLERRM ~ '^ERR_[A-Z0-9_]+$' THEN SQLERRM
          ELSE 'ERR_PUBLICATION_FAILED'
        END
      WHERE id = v_version_id;

      RETURN private.build_rpc_error(
        NULL,
        'ERR_PUBLICATION_FAILED',
        'Read-model publication failed.'
      );
  END;

  -- STEP 03: Flip all page and search readers to the complete candidate atomically.
  UPDATE public.publication_versions
  SET
    is_current = FALSE,
    status = 'retired'
  WHERE is_current = TRUE;

  UPDATE public.publication_versions
  SET
    status = 'published',
    is_current = TRUE,
    published_at = now()
  WHERE id = v_version_id;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'data_version', v_version_id,
      'route_options', v_route_count,
      'pages', v_page_counts
    ),
    'meta', jsonb_build_object('data_version', v_version_id, 'published_at', now()),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.publish_read_model_version(TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_read_model_version(TEXT) TO service_role;
