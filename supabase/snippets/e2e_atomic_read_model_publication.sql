\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(p_condition BOOLEAN, p_message TEXT)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT COALESCE(p_condition, FALSE) THEN
    RAISE EXCEPTION 'ASSERTION FAILED: %', p_message;
  END IF;
END;
$$;

CREATE TEMPORARY TABLE previous_publication AS
SELECT id
FROM public.publication_versions
WHERE is_current = TRUE;

DELETE FROM public.route_options;

SELECT pg_temp.test_assert(
  public.publish_read_model_version('development_fixture') #>> '{error,code}'
    = 'ERR_PUBLICATION_FAILED',
  'an incomplete candidate fails publication'
);

SELECT pg_temp.test_assert(
  (SELECT id FROM public.publication_versions WHERE is_current = TRUE)
    = (SELECT id FROM previous_publication),
  'a failed candidate leaves the previous version current'
);

SELECT pg_temp.test_assert(
  EXISTS (
    SELECT 1
    FROM public.publication_versions
    WHERE status = 'failed'
      AND failure_code = 'ERR_PUBLICATION_INCOMPLETE'
  ),
  'a failed candidate records its stable failure reason'
);

ROLLBACK;
