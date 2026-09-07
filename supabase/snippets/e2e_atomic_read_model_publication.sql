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

-- Insert a stale retired version to verify pruning.
INSERT INTO public.publication_versions (
  status,
  is_current,
  source_type,
  published_at,
  created_at
)
VALUES (
  'retired',
  FALSE,
  'development_fixture',
  now() - INTERVAL '2 hours',
  now() - INTERVAL '2 hours'
);

SAVEPOINT before_failed_candidate;

DELETE FROM public.direct_flight_routes;

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

ROLLBACK TO SAVEPOINT before_failed_candidate;

-- Successful publication should prune older retired and failed versions, retaining only current and immediate rollback.
SELECT pg_temp.test_assert(
  public.publish_read_model_version('development_fixture') #>> '{error}' IS NULL,
  'a valid candidate publishes successfully'
);

SELECT pg_temp.test_assert(
  (SELECT count(*) FROM public.publication_versions) = 2,
  'publication prunes stale versions and preserves exactly current and immediate rollback'
);

SELECT pg_temp.test_assert(
  (SELECT count(*) FROM public.publication_versions WHERE is_current = TRUE AND status = 'published') = 1,
  'exactly one version is published and current'
);

SELECT pg_temp.test_assert(
  (SELECT count(*) FROM public.publication_versions WHERE is_current = FALSE AND status = 'retired') = 1,
  'exactly one version is retired as immediate rollback'
);

ROLLBACK;
