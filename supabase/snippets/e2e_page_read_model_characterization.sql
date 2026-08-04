\set ON_ERROR_STOP on
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.test_assert(p_condition BOOLEAN,p_message TEXT) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF NOT COALESCE(p_condition,FALSE) THEN RAISE EXCEPTION 'ASSERTION FAILED: %',p_message;END IF;END;$$;
SELECT pg_temp.test_assert(to_regclass('public.homepage_read_models') IS NOT NULL,'homepage has a dedicated read model');
SELECT pg_temp.test_assert(to_regclass('public.city_page_read_models') IS NOT NULL,'city has a dedicated read model');
SELECT pg_temp.test_assert(to_regclass('public.airport_page_read_models') IS NOT NULL,'airport has a dedicated read model');
SELECT pg_temp.test_assert(to_regclass('public.route_page_read_models') IS NOT NULL,'route has a dedicated read model');
SELECT pg_temp.test_assert(to_regclass('public.route_search_options') IS NOT NULL,'all pages share one route search projection');
ROLLBACK;
