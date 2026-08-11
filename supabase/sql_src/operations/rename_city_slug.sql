-- ============================================================================
-- Function: private.rename_city_slug
-- Purpose: Rename a city slug and every canonical pSEO identity that embeds it.
-- Notes: Service-role operation. Publish a new read-model version after calling.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.rename_city_slug(
  p_current_slug TEXT,
  p_new_slug TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_city_id UUID;
  v_current_slug TEXT := lower(btrim(p_current_slug));
  v_new_slug TEXT := lower(btrim(p_new_slug));
  v_city_page_count INTEGER := 0;
  v_route_page_count INTEGER := 0;
  v_registry_count INTEGER := 0;
  v_placeholder_registry_count INTEGER := 0;
BEGIN
  IF v_current_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
     OR v_new_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' THEN
    RAISE EXCEPTION 'ERR_CITY_SLUG_INVALID';
  END IF;

  SELECT city.id
  INTO v_city_id
  FROM public.cities AS city
  WHERE city.slug = v_current_slug
  FOR UPDATE;

  IF v_city_id IS NULL THEN
    RAISE EXCEPTION 'ERR_CITY_NOT_FOUND';
  END IF;

  IF v_current_slug = v_new_slug THEN
    RETURN jsonb_build_object(
      'city_id', v_city_id,
      'old_slug', v_current_slug,
      'new_slug', v_new_slug,
      'city_pages_updated', 0,
      'route_pages_updated', 0,
      'registry_pages_updated', 0
    );
  END IF;

  IF EXISTS (SELECT 1 FROM public.cities AS city WHERE city.slug = v_new_slug) THEN
    RAISE EXCEPTION 'ERR_CITY_SLUG_CONFLICT';
  END IF;

  UPDATE public.cities
  SET slug = v_new_slug,
      updated_at = now()
  WHERE id = v_city_id;

  UPDATE public.city_pages AS city_page
  SET og_image_path = CASE
        WHEN city_page.og_image_path = '/og/flights-from/' || v_current_slug || '.png'
          THEN '/og/flights-from/' || v_new_slug || '.png'
        ELSE city_page.og_image_path
      END,
      updated_at = now()
  WHERE city_page.city_id = v_city_id;
  GET DIAGNOSTICS v_city_page_count = ROW_COUNT;

  UPDATE public.pseo_pages AS registry
  SET entity_key = v_new_slug,
      canonical_path = '/flights-from/' || v_new_slug,
      content_updated_at = now(),
      generated_at = now()
  FROM public.city_pages AS city_page
  WHERE city_page.pseo_page_id = registry.id
    AND city_page.city_id = v_city_id;
  GET DIAGNOSTICS v_registry_count = ROW_COUNT;

  UPDATE public.pseo_pages AS registry
  SET entity_key = origin_city.slug || '-to-' || destination_city.slug,
      canonical_path = '/flights/' || origin_city.slug || '-to-' || destination_city.slug,
      content_updated_at = now(),
      generated_at = now()
  FROM public.route_pages AS route_page
  JOIN public.cities AS origin_city ON origin_city.id = route_page.origin_city_id
  JOIN public.cities AS destination_city ON destination_city.id = route_page.destination_city_id
  WHERE route_page.pseo_page_id = registry.id
    AND (route_page.origin_city_id = v_city_id OR route_page.destination_city_id = v_city_id);
  GET DIAGNOSTICS v_route_page_count = ROW_COUNT;

  UPDATE public.pseo_pages AS registry
  SET entity_key = CASE
        WHEN registry.entity_key LIKE v_current_slug || ':%'
          THEN v_new_slug || substr(registry.entity_key, char_length(v_current_slug) + 1)
        WHEN registry.entity_key LIKE '%:' || v_current_slug
          THEN left(registry.entity_key, char_length(registry.entity_key) - char_length(v_current_slug)) || v_new_slug
        ELSE registry.entity_key
      END,
      canonical_path = CASE
        WHEN registry.canonical_path LIKE '/flights/' || v_current_slug || '-to-%'
          THEN '/flights/' || v_new_slug || substr(
            registry.canonical_path,
            char_length('/flights/' || v_current_slug) + 1
          )
        WHEN registry.canonical_path LIKE '/flights/%-to-' || v_current_slug
          THEN left(registry.canonical_path, char_length(registry.canonical_path) - char_length(v_current_slug)) || v_new_slug
        ELSE registry.canonical_path
      END,
      content_updated_at = now(),
      generated_at = now()
  WHERE registry.page_type = 'city_route'
    AND (
      registry.entity_key LIKE v_current_slug || ':%'
      OR registry.entity_key LIKE '%:' || v_current_slug
    );
  GET DIAGNOSTICS v_placeholder_registry_count = ROW_COUNT;
  v_registry_count := v_registry_count + v_placeholder_registry_count;

  RETURN jsonb_build_object(
    'city_id', v_city_id,
    'old_slug', v_current_slug,
    'new_slug', v_new_slug,
    'city_pages_updated', v_city_page_count,
    'route_pages_updated', v_route_page_count,
    'registry_pages_updated', v_registry_count
  );
END;
$$;

REVOKE ALL ON FUNCTION private.rename_city_slug(TEXT, TEXT)
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.rename_city_slug(TEXT, TEXT) TO service_role;
