\set ON_ERROR_STOP on
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.test_assert(p_condition BOOLEAN,p_message TEXT) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF NOT COALESCE(p_condition,FALSE) THEN RAISE EXCEPTION 'ASSERTION FAILED: %',p_message; END IF; END; $$;
SELECT pg_temp.test_assert(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.rpc_get_sitemap('{}')#>'{data}') item WHERE item->>'path'='/flights/ho-chi-minh-city-to-london'),'development fixture route page is excluded from sitemap');
SELECT pg_temp.test_assert((SELECT bool_and(is_indexable=FALSE AND noindex_reason='development_fixture') FROM public.pseo_pages WHERE data_version IS NOT NULL),'fixture lineage remains noindex');
SELECT public.refresh_pseo_read_models();
SELECT pg_temp.test_assert((SELECT is_indexable=FALSE AND noindex_reason='development_fixture' FROM public.route_pages WHERE canonical_slug='ho-chi-minh-city-to-london'),'refresh cannot promote fixture route page');
ROLLBACK;
