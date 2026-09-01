\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(
  p_condition BOOLEAN,
  p_message TEXT
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT COALESCE(p_condition, FALSE) THEN
    RAISE EXCEPTION 'ASSERTION FAILED: %', p_message;
  END IF;
END;
$$;

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(public.rpc_get_sitemap('{}') #> '{data}') AS item
    WHERE item->>'path' = '/flights/ho-chi-minh-city-to-london'
  ),
  'development fixture route page is excluded from sitemap'
);

SELECT public.publish_read_model_version('development_fixture');

SELECT pg_temp.test_assert(
  (
    SELECT NOT is_indexable AND noindex_reason = 'development_fixture'
    FROM public.pseo_pages
    WHERE canonical_path = '/flights/ho-chi-minh-city-to-london'
  ),
  'republishing a fixture cannot promote its route page'
);

ROLLBACK;
