-- ============================================================================
-- Function: admin.build_city_page_payload
-- Purpose: Compose one public-safe City page payload for a publication candidate.
-- Responsibilities: Allowlist city identity, content, routes, and lifecycle metadata.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.build_city_page_payload(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_slug      TEXT := lower(p_input->>'city_slug');
  v_locale    TEXT := COALESCE(NULLIF(p_input->>'locale', ''), 'en-GB');
  v_direction TEXT := COALESCE(NULLIF(p_input->>'route_direction', ''), 'outbound');
  v_version   UUID := (p_input->>'publication_version_id')::UUID;
  v_page      public.city_pages%ROWTYPE;
  v_city      public.cities%ROWTYPE;
  v_registry  public.pseo_pages%ROWTYPE;
BEGIN
  SELECT page.*
  INTO v_page
  FROM public.city_pages AS page
  JOIN public.pseo_pages AS registry
    ON registry.id = page.pseo_page_id
  WHERE registry.entity_key = v_slug
    AND page.locale = v_locale
    AND page.route_direction = v_direction;

  IF v_page.id IS NULL THEN
    RETURN admin.build_rpc_error(NULL, 'ERR_NOT_FOUND', 'City page not found.');
  END IF;

  SELECT * INTO v_city FROM public.cities WHERE id = v_page.city_id;
  SELECT * INTO v_registry FROM public.pseo_pages WHERE id = v_page.pseo_page_id;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'city', jsonb_build_object(
        'name', v_city.name,
        'slug', v_city.slug,
        'iata_code', v_city.iata_code,
        'timezone', v_city.timezone,
        'currency_code', v_city.currency_code,
        'primary_language', v_city.primary_language
      ),
      'content', v_page.content,
      'flight_data_state', CASE
        WHEN EXISTS (
          SELECT 1
          FROM public.flight_route_options AS option
          WHERE option.publication_version_id = v_version
            AND option.origin_city_id = v_city.id
        ) THEN 'available'
        WHEN EXISTS (
          SELECT 1
          FROM admin.flight_route_cache_states AS cache
          WHERE cache.origin_iata = v_city.iata_code
            AND cache.status IN ('empty', 'failed')
            AND cache.next_refresh_at > now()
        ) THEN 'unavailable'
        ELSE 'loading'
      END,
      'routes', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'from', option.origin_airport_iata,
          'to', option.destination_airport_iata,
          'airline', option.provider_airline_iata,
          'observed_amount', option.observed_amount,
          'currency_code', option.currency_code,
          'valid_until', option.observation_valid_until,
          'route_path', option.route_path
        ) ORDER BY option.confidence_score DESC, option.observed_amount NULLS LAST)
        FROM public.flight_route_options AS option
        WHERE option.publication_version_id = v_version
          AND (
            (v_direction = 'outbound' AND option.origin_city_id = v_city.id)
            OR (v_direction = 'inbound' AND option.destination_city_id = v_city.id)
          )
      ), '[]'::JSONB)
    ),
    'meta', jsonb_build_object(
      'canonical_path', v_registry.canonical_path,
      'is_indexable', v_registry.is_indexable,
      'noindex_reason', v_registry.noindex_reason,
      'data_version', 'v_' || md5(v_version::TEXT),
      'source_freshness_at', v_registry.source_freshness_at
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.build_city_page_payload(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.build_city_page_payload(JSONB) TO service_role;
