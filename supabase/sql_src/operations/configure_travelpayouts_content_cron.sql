-- Install a daily freshness check for Travelpayouts content observations.
-- The provider is called only when no published row is newer than six days.
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION private.configure_travelpayouts_content_cron()
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_job_id BIGINT;
BEGIN
  PERFORM cron.unschedule(job.jobid)
  FROM cron.job AS job
  WHERE job.jobname = 'tripways-travelpayouts-content-daily-check';

  SELECT cron.schedule(
    'tripways-travelpayouts-content-daily-check',
    '20 2 * * *',
    $cron$
      SELECT net.http_post(
        url := (SELECT secret.decrypted_secret FROM vault.decrypted_secrets secret WHERE secret.name='project_url') || '/functions/v1/ingestion-price-estimates',
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'Authorization','Bearer ' || (SELECT secret.decrypted_secret FROM vault.decrypted_secrets secret WHERE secret.name='ingestion_worker_secret'),
          'Idempotency-Key','travelpayouts-content-' || to_char(CURRENT_DATE,'YYYY-MM-DD')
        ),
        body := jsonb_build_object('sourceCode','travelpayouts','providerKey','travelpayouts')
      )
      WHERE NOT EXISTS (
        SELECT 1
        FROM public.flight_content_observations observation
        JOIN admin.data_sources source ON source.id=observation.source_id
        WHERE source.code='travelpayouts'
          AND observation.status='published'
          AND observation.valid_until > now()
          AND observation.observed_at > now() - interval '6 days'
      );
    $cron$
  ) INTO v_job_id;
  RETURN v_job_id;
END;
$$;

REVOKE ALL ON FUNCTION private.configure_travelpayouts_content_cron() FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.configure_travelpayouts_content_cron() TO service_role;
