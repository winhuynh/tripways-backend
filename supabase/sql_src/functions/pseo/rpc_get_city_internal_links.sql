-- ============================================================================
-- Function: public.rpc_get_city_internal_links
-- Feature: Interactive pSEO
-- Purpose: Return reviewed semantic internal links grouped by cluster.
-- Responsibilities: Preserve relevance, display order, and crawlable target paths.
-- Notes: Archived targets are excluded.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_city_internal_links(p_input JSONB)
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
  v_pseo_page_id UUID;
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

  v_pseo_page_id := (v_context #>> '{data,pseo_page_id}')::UUID;

  SELECT jsonb_build_object(
    'data', COALESCE(jsonb_agg(
      jsonb_build_object(
        'cluster', link_group.link_cluster,
        'links', link_group.links
      )
      ORDER BY link_group.cluster_order
    ), '[]'::JSONB),
    'meta', '{}'::JSONB,
    'error', NULL
  )
  INTO v_result
  FROM (
    SELECT
      internal_link.link_cluster,
      min(internal_link.display_order) AS cluster_order,
      jsonb_agg(
        jsonb_build_object(
          'title', target_page.display_title,
          'path', target_page.canonical_path,
          'anchor_text', internal_link.anchor_text,
          'secondary_text', internal_link.secondary_text,
          'is_featured', internal_link.is_featured
        )
        ORDER BY internal_link.display_order, internal_link.relevance_score DESC
      ) AS links
    FROM public.pseo_internal_links internal_link
    JOIN public.pseo_pages target_page
      ON target_page.id = internal_link.target_page_id
    WHERE internal_link.source_page_id = v_pseo_page_id
      AND target_page.status <> 'archived'
    GROUP BY internal_link.link_cluster
  ) link_group;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_city_internal_links(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_city_internal_links(JSONB) TO service_role;
