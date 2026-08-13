\set ON_ERROR_STOP on

SELECT admin.sync_provider_pseo_pages('development_fixture');
SELECT public.publish_read_model_version('development_fixture');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.city_page_read_models WHERE canonical_slug = 'london'
  ) THEN
    RAISE EXCEPTION 'London preview city page was not generated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.airport_page_read_models WHERE airport_iata = 'LHR'
  ) THEN
    RAISE EXCEPTION 'LHR preview airport page was not generated';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.route_page_read_models
    WHERE canonical_slug = 'ho-chi-minh-city-london'
  ) THEN
    RAISE EXCEPTION 'Ho Chi Minh City to London preview route page was not generated';
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
