\set ON_ERROR_STOP on

DO $$
DECLARE
  v_version_id UUID;
  v_page JSONB;
  v_search JSONB;
BEGIN
  SELECT version.id
  INTO v_version_id
  FROM public.publication_versions AS version
  WHERE version.is_current;

  IF v_version_id IS NULL THEN
    RAISE EXCEPTION 'current publication is missing';
  END IF;

  IF to_regclass('public.route_options') IS NOT NULL
    OR to_regclass('public.pseo_direct_routes') IS NOT NULL
    OR to_regclass('public.city_destination_summaries') IS NOT NULL
  THEN
    RAISE EXCEPTION 'legacy route projection still exists';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.route_search_options WHERE publication_version_id <> v_version_id
  ) OR EXISTS (
    SELECT 1 FROM public.city_page_read_models WHERE publication_version_id <> v_version_id
  ) OR EXISTS (
    SELECT 1 FROM public.airport_page_read_models WHERE publication_version_id <> v_version_id
  ) OR EXISTS (
    SELECT 1 FROM public.route_page_read_models WHERE publication_version_id <> v_version_id
  ) THEN
    RAISE EXCEPTION 'published consumers do not share one version';
  END IF;

  v_page := public.rpc_get_page(jsonb_build_object(
    'page_type', 'city',
    'entity_key', 'bangkok',
    'locale', 'en-GB'
  ));
  v_search := public.rpc_search_routes(jsonb_build_object(
    'scope', jsonb_build_object('type', 'origin_city', 'key', 'bangkok'),
    'filters', jsonb_build_object('max_stops', 0),
    'page_size', 20
  ));

  IF (v_page #>> '{meta,data_version}')::UUID <> v_version_id
    OR (v_search #>> '{meta,data_version}')::UUID <> v_version_id
  THEN
    RAISE EXCEPTION 'page and search RPC versions differ';
  END IF;
END;
$$;
