-- ============================================================================
-- Function: admin.configure_ingestion_crons
-- Purpose: Install base data ingestion schedule.
-- Responsibilities: Validate Vault and replace base data job idempotently.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION admin.configure_ingestion_crons()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_project_url       TEXT;
  v_worker_secret     TEXT;
  v_ourairports_job   BIGINT;
BEGIN
  SELECT secret.decrypted_secret
  INTO v_project_url
  FROM vault.decrypted_secrets AS secret
  WHERE secret.name = 'project_url';

  SELECT secret.decrypted_secret
  INTO v_worker_secret
  FROM vault.decrypted_secrets AS secret
  WHERE secret.name = 'ingestion_worker_secret';

  IF v_project_url IS NULL
    OR v_project_url !~ '^https://'
    OR v_worker_secret IS NULL
    OR char_length(v_worker_secret) < 16
  THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_CRON_VAULT_PREREQUISITES_MISSING';
  END IF;

  PERFORM cron.unschedule(job.jobid)
  FROM cron.job AS job
  WHERE job.jobname IN (
    'tripways-ourairports-daily'
  );

  SELECT cron.schedule(
    'tripways-ourairports-daily',
    '0 2 * * *',
    $cron$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/ingestion-base-data',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'ingestion_worker_secret'),
          'Idempotency-Key', 'ourairports-' || to_char(CURRENT_DATE, 'YYYY-MM-DD')
        ),
        body := jsonb_build_object('sourceCode', 'ourairports', 'providerMode', 'ourairports')
      );$cron$
  )
  INTO v_ourairports_job;

  RETURN jsonb_build_object(
    'ourairports_job_id', v_ourairports_job
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.configure_ingestion_crons()
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.configure_ingestion_crons() TO service_role;

