-- ============================================================================
-- Function: public.rpc_get_city_quick_facts
-- Feature: Interactive pSEO
-- Purpose: Return one independently loadable city Quick Facts read model.
-- Responsibilities: Resolve page identity and compose the shared RPC envelope.
-- Notes: Facts are derived from the city page's current data version.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_city_quick_facts(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Input and resolved context
  ------------------------------------------------------------------
  v_identity JSONB := private.parse_city_page_identity(p_input);
  v_context JSONB;
  v_city_slug TEXT;
  v_locale TEXT;
  v_city_id UUID;
  v_data_version UUID;
BEGIN
  -- STEP 01: Validate the shared city-page identity.
  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      v_identity #>> '{error,code}',
      v_identity #>> '{error,message}'
    );
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';
  v_context := private.resolve_city_page_context(
    v_city_slug,
    v_locale
  );

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      v_context #>> '{error,code}',
      v_context #>> '{error,message}'
    );
  END IF;

  v_city_id := (v_context #>> '{data,city_id}')::UUID;
  v_data_version := (v_context #>> '{data,data_version}')::UUID;

  -- STEP 02: Return one helper-owned, version-consistent read model.
  RETURN jsonb_build_object(
    'data', private.get_city_quick_facts(
      v_city_id,
      v_data_version
    ),
    'meta', jsonb_build_object(
      'city_slug', v_city_slug,
      'locale', v_locale,
      'data_version', v_data_version
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_city_quick_facts(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_city_quick_facts(JSONB) TO service_role;
