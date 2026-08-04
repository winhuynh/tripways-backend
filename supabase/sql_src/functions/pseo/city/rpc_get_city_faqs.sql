-- ============================================================================
-- Function: public.rpc_get_city_faqs
-- Feature: Interactive pSEO
-- Purpose: Return published FAQs for visible content and FAQPage structured data.
-- Responsibilities: Preserve reviewed display order and answer type.
-- Notes: Hidden or draft FAQs never reach the public read model.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_city_faqs(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_identity JSONB := private.parse_city_page_identity(p_input);
  v_context JSONB;
  v_city_slug TEXT;
  v_locale TEXT;
  v_city_page_id UUID;
  v_result JSONB;
BEGIN
  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error('[]'::JSONB, v_identity #>> '{error,code}', v_identity #>> '{error,message}');
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';
  v_context := private.resolve_city_page_context(v_city_slug, v_locale);

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error('[]'::JSONB, v_context #>> '{error,code}', v_context #>> '{error,message}');
  END IF;

  v_city_page_id := (v_context #>> '{data,city_page_id}')::UUID;

  SELECT jsonb_build_object(
    'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'question', faq.question,
        'answer', faq.answer,
        'answer_type', faq.answer_type
      )
      ORDER BY faq.display_order
    ), '[]'::JSONB),
    'meta', '{}'::JSONB,
    'error', NULL
  )
  INTO v_result
  FROM public.city_page_faqs faq
  WHERE faq.city_page_id = v_city_page_id
    AND faq.status = 'published';

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_city_faqs(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_city_faqs(JSONB) TO service_role;
