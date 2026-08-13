-- ============================================================================
-- Function: public.rpc_get_sitemap
-- Purpose: Return the current set of indexable canonical pSEO URLs.
-- Responsibilities: Apply publication and locale filters at the database boundary.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_sitemap(p_input JSONB DEFAULT '{}'::JSONB)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'data', COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'path', page.canonical_path,
          'locale', page.locale,
          'page_type', page.page_type,
          'last_modified', page.content_updated_at
        )
        ORDER BY page.canonical_path
      ),
      '[]'::JSONB
    ),
    'meta', jsonb_build_object('only_indexable', TRUE),
    'error', NULL
  )
  FROM public.pseo_pages AS page
  WHERE page.status = 'published'
    AND page.is_indexable
    AND page.noindex_reason IS NULL
    AND (
      NOT p_input ? 'locale'
      OR page.locale = p_input->>'locale'
    );
$$;

REVOKE ALL ON FUNCTION public.rpc_get_sitemap(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_sitemap(JSONB) TO service_role;
