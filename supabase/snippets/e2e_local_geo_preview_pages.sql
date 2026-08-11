\set ON_ERROR_STOP on

SELECT private.generate_local_geo_preview_pages();
SELECT public.publish_read_model_version('development_fixture');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.city_page_read_models WHERE canonical_slug = 'annecy'
  ) THEN
    RAISE EXCEPTION 'Annecy preview city page was not generated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.airport_page_read_models WHERE airport_iata = 'NCY'
  ) THEN
    RAISE EXCEPTION 'NCY preview airport page was not generated';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.route_page_read_models
    WHERE canonical_slug = 'bangkok-thailand-to-singapore'
  ) THEN
    RAISE EXCEPTION 'Bangkok to Singapore preview route page was not generated';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.city_pages AS city_page
    JOIN public.cities AS city ON city.id = city_page.city_id
    JOIN public.pseo_pages AS registry ON registry.id = city_page.pseo_page_id
    WHERE city.slug = 'aberdeen'
      AND registry.status = 'draft'
  ) THEN
    RAISE EXCEPTION 'ambiguous city slug received an unsafe preview page';
  END IF;
END;
$$;
