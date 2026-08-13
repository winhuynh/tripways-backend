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
  IF p_source_type NOT IN ('production', 'staging', 'development_fixture') THEN
    RETURN admin.build_rpc_error(NULL, 'ERR_INVALID_REQUEST', 'Invalid publication source type.');
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
    v_route_count := admin.refresh_route_search_options(v_version_id);

    -- STEP 02A: Derive both constrained lifecycle fields in one registry update.
    WITH page_eligibility AS (
      SELECT
        registry.id,
        p_source_type = 'production'
        AND registry.status = 'published'
        AND CASE
        WHEN registry.page_type = 'city' THEN EXISTS (
          SELECT 1
          FROM public.city_pages AS content
          JOIN public.flight_route_options AS route
           ON route.publication_version_id = v_version_id
           AND route.origin_city_id = content.city_id
          WHERE content.pseo_page_id = registry.id
            AND content.content_reviewed_at IS NOT NULL
        )
        WHEN registry.page_type = 'airport' THEN EXISTS (
          SELECT 1
          FROM public.airport_pages AS content
          JOIN public.flight_route_options AS route
           ON route.publication_version_id = v_version_id
           AND route.origin_airport_id = content.airport_id
          WHERE content.pseo_page_id = registry.id
            AND content.content_reviewed_at IS NOT NULL
        )
        WHEN registry.page_type = 'city_route' THEN EXISTS (
          SELECT 1
          FROM public.route_pages AS content
          JOIN public.flight_route_options AS route
            ON route.publication_version_id = v_version_id
           AND route.origin_city_id = content.origin_city_id
           AND route.destination_city_id = content.destination_city_id
          WHERE content.pseo_page_id = registry.id
            AND content.content_reviewed_at IS NOT NULL
        )
        ELSE FALSE
        END AS is_eligible
      FROM public.pseo_pages AS registry
    )
    UPDATE public.pseo_pages AS registry
    SET
      is_indexable = eligibility.is_eligible,
      noindex_reason = CASE
        WHEN eligibility.is_eligible THEN NULL
        WHEN p_source_type = 'development_fixture' THEN 'development_fixture'
        WHEN p_source_type = 'staging' THEN 'staging_environment'
        WHEN registry.status <> 'published' THEN 'not_published'
        WHEN registry.page_type IN ('city', 'airport', 'city_route') THEN 'source_not_seo_eligible'
        ELSE COALESCE(registry.noindex_reason, 'unsupported_page_type')
      END,
      data_version = v_version_id,
      generated_at = now()
    FROM page_eligibility AS eligibility
    WHERE eligibility.id = registry.id;

    v_page_counts := admin.refresh_page_read_models(v_version_id);

    IF v_route_count = 0 THEN
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

      RETURN admin.build_rpc_error(
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
