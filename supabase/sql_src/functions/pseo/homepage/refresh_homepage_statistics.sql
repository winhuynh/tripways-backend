-- ============================================================================
-- Function: private.refresh_homepage_statistics
-- Purpose: Replace the homepage coverage snapshot for one candidate publication.
-- Responsibilities: Aggregate direct-route coverage before publication becomes current.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.refresh_homepage_statistics(p_publication_version_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
VOLATILE
SET search_path = ''
AS $$
DECLARE
  v_row_count INTEGER;
BEGIN
  DELETE FROM public.homepage_statistics;

  INSERT INTO public.homepage_statistics (
    city_count,
    airport_count,
    direct_route_count,
    data_version,
    generated_at
  )
  SELECT
    count(DISTINCT option.origin_city_id)::INTEGER,
    count(DISTINCT option.origin_airport_id)::INTEGER,
    count(DISTINCT option.route_path)::INTEGER,
    p_publication_version_id,
    now()
  FROM public.route_search_options option
  WHERE option.publication_version_id = p_publication_version_id
    AND option.stop_count = 0;

  GET DIAGNOSTICS v_row_count = ROW_COUNT;
  RETURN v_row_count;
END;
$$;

REVOKE ALL ON FUNCTION private.refresh_homepage_statistics(UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.refresh_homepage_statistics(UUID) TO service_role;
