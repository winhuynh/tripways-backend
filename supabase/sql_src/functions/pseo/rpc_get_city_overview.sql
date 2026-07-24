-- ============================================================================
-- Function: public.rpc_get_city_overview
-- Feature: Interactive pSEO
-- Purpose: Return the required identity, publication metadata, and quick facts for a city page.
-- Responsibilities: Resolve city context and expose one bounded above-the-fold read model.
-- Notes: Database-owned indexability controls web metadata and robots output.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_city_overview(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_identity JSONB;
  v_context JSONB;
  v_city_slug TEXT;
  v_locale TEXT;
  v_city_id UUID;
  v_result JSONB;
BEGIN
  v_identity := private.parse_city_page_identity(p_input);

  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      v_identity #>> '{error,code}',
      v_identity #>> '{error,message}'
    );
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';
  v_context := private.resolve_city_page_context(v_city_slug, v_locale);

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      v_context #>> '{error,code}',
      v_context #>> '{error,message}'
    );
  END IF;

  v_city_id := (v_context #>> '{data,city_id}')::UUID;

  SELECT jsonb_build_object(
    'data', jsonb_build_object(
      'city', jsonb_build_object(
        'name', city.name,
        'slug', city.slug,
        'latitude', city.latitude,
        'longitude', city.longitude,
        'timezone', city.timezone
      ),
      'country', jsonb_build_object(
        'iso2', country.iso2,
        'name', country.name,
        'slug', country.slug,
        'region', country.region
      ),
      'content', jsonb_build_object(
        'h1', city_page.h1,
        'subheadline', city_page.subheadline,
        'intro', city_page.intro,
        'airport_summary', city_page.airport_summary
      ),
      'seo', jsonb_build_object(
        'title', city_page.seo_title,
        'description', city_page.meta_description,
        'canonical_path', pseo_page.canonical_path,
        'og_title', city_page.og_title,
        'og_description', city_page.og_description,
        'og_image_path', city_page.og_image_path,
        'is_indexable', city_page.is_indexable,
        'noindex_reason', city_page.noindex_reason
      ),
      'quick_facts', jsonb_build_object(
        'airport_count', city_page.airport_count,
        'direct_destination_count', city_page.direct_destination_count,
        'direct_country_count', city_page.direct_country_count,
        'airline_count', city_page.airline_count,
        'shortest_route_minutes', city_page.shortest_route_minutes,
        'longest_route_minutes', city_page.longest_route_minutes
      )
    ),
    'meta', jsonb_build_object(
      'data_version', city_page.data_version,
      'generated_at', city_page.generated_at,
      'source_freshness_at', city_page.source_freshness_at
    ),
    'error', NULL
  )
  INTO v_result
  FROM public.cities city
  JOIN public.countries country
    ON country.id = city.country_id
  JOIN public.city_pages city_page
    ON city_page.city_id = city.id
    AND city_page.locale = v_locale
  JOIN public.pseo_pages pseo_page
    ON pseo_page.id = city_page.pseo_page_id
  WHERE city.id = v_city_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_city_overview(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_city_overview(JSONB) TO service_role;
