\set ON_ERROR_STOP on

SELECT private.rename_city_slug('bangkok', 'bangkok-thailand');

DO $$
DECLARE
  v_payload JSONB;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.cities
    WHERE slug = 'bangkok-thailand'
  ) THEN
    RAISE EXCEPTION 'city slug was not updated';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.pseo_pages
    WHERE page_type = 'city'
      AND entity_key = 'bangkok'
  ) THEN
    RAISE EXCEPTION 'old city page slug remains';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.pseo_pages
    WHERE canonical_path LIKE '/flights/bangkok-to-%'
       OR canonical_path LIKE '/flights/%-to-bangkok'
  ) THEN
    RAISE EXCEPTION 'old route canonical path remains';
  END IF;

  PERFORM public.publish_read_model_version('development_fixture');

  SELECT public.rpc_get_page(jsonb_build_object(
    'page_type', 'city',
    'entity_key', 'bangkok-thailand',
    'locale', 'en-GB'
  ))
  INTO v_payload;

  IF v_payload #>> '{data,city,slug}' <> 'bangkok-thailand' THEN
    RAISE EXCEPTION 'new slug is not readable from the published model';
  END IF;

  IF (public.rpc_get_page(jsonb_build_object(
    'page_type', 'city',
    'entity_key', 'bangkok',
    'locale', 'en-GB'
  )) #>> '{error,code}') <> 'ERR_PAGE_NOT_FOUND' THEN
    RAISE EXCEPTION 'old slug is still readable';
  END IF;
END;
$$;

-- Restore the production canonical identity so this verification is safe to run locally.
SELECT private.rename_city_slug('bangkok-thailand', 'bangkok');
SELECT public.publish_read_model_version('development_fixture');

DO $$
BEGIN
  IF (public.rpc_get_page(jsonb_build_object(
    'page_type', 'city',
    'entity_key', 'bangkok',
    'locale', 'en-GB'
  )) #>> '{data,city,slug}') <> 'bangkok' THEN
    RAISE EXCEPTION 'production city slug was not restored';
  END IF;

  IF (public.rpc_get_page(jsonb_build_object(
    'page_type', 'city',
    'entity_key', 'bangkok-thailand',
    'locale', 'en-GB'
  )) #>> '{error,code}') <> 'ERR_PAGE_NOT_FOUND' THEN
    RAISE EXCEPTION 'temporary QA slug remains readable';
  END IF;
END;
$$;
