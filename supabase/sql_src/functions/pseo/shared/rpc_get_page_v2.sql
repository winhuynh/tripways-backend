-- ============================================================================
-- Function: public.rpc_get_page_v2
-- Purpose: Load one complete page from its dedicated current read model.
-- Responsibilities: Normalize identity and perform exactly one page-model lookup.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_page_v2(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_page_type TEXT := p_input->>'page_type';
  v_entity_key TEXT := p_input->>'entity_key';
  v_locale TEXT := COALESCE(NULLIF(p_input->>'locale', ''), 'en-GB');
  v_version_id UUID;
  v_payload JSONB;
  v_generated_at TIMESTAMPTZ;
BEGIN
  IF v_page_type NOT IN ('homepage', 'city', 'airport', 'route')
    OR v_entity_key IS NULL
    OR v_locale !~ '^[a-z]{2}(?:-[A-Z]{2})?$'
  THEN
    RETURN private.build_rpc_error(NULL, 'ERR_INVALID_REQUEST', 'Invalid page request.');
  END IF;

  -- STEP 01: Select the requested row and its current version in one indexed statement.
  IF v_page_type = 'homepage' THEN
    SELECT model.payload, model.generated_at, version.id
    INTO v_payload, v_generated_at, v_version_id
    FROM public.homepage_read_models model
    INNER JOIN public.publication_versions version
      ON version.id = model.publication_version_id
      AND version.is_current = TRUE
    WHERE model.locale = v_locale;
  ELSIF v_page_type = 'city' THEN
    SELECT model.payload, model.generated_at, version.id
    INTO v_payload, v_generated_at, v_version_id
    FROM public.city_page_read_models model
    INNER JOIN public.publication_versions version
      ON version.id = model.publication_version_id
      AND version.is_current = TRUE
    WHERE model.canonical_slug = lower(v_entity_key)
      AND model.locale = v_locale;
  ELSIF v_page_type = 'airport' THEN
    SELECT model.payload, model.generated_at, version.id
    INTO v_payload, v_generated_at, v_version_id
    FROM public.airport_page_read_models model
    INNER JOIN public.publication_versions version
      ON version.id = model.publication_version_id
      AND version.is_current = TRUE
    WHERE model.airport_iata = upper(v_entity_key)
      AND model.locale = v_locale;
  ELSE
    SELECT model.payload, model.generated_at, version.id
    INTO v_payload, v_generated_at, v_version_id
    FROM public.route_page_read_models model
    INNER JOIN public.publication_versions version
      ON version.id = model.publication_version_id
      AND version.is_current = TRUE
    WHERE model.canonical_slug = lower(v_entity_key)
      AND model.locale = v_locale;
  END IF;

  IF v_payload IS NULL THEN
    RETURN private.build_rpc_error(NULL, 'ERR_PAGE_NOT_FOUND', 'Current page not found.');
  END IF;

  -- STEP 02: Return the materialized payload without rebuilding page modules at request time.
  RETURN jsonb_build_object(
    'data', v_payload,
    'meta', jsonb_build_object(
      'page_type', v_page_type,
      'entity_key', v_entity_key,
      'data_version', v_version_id,
      'generated_at', v_generated_at
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_page_v2(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_page_v2(JSONB) TO service_role;
