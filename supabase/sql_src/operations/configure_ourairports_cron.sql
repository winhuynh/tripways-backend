-- ============================================================================
-- Function: private.configure_ourairports_cron
-- Purpose: Install the daily OurAirports ingestion trigger after Vault secrets exist.
-- Responsibilities: Keep environment-specific URL and worker credentials in Supabase Vault.
-- Notes: Requires Vault secrets project_url and ingestion_worker_secret.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION private.configure_ourairports_cron()
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_job_id  BIGINT;
BEGIN
  PERFORM cron.unschedule(job.jobid)
  FROM cron.job AS job
  WHERE job.jobname = 'tripways-ourairports-daily';

  SELECT cron.schedule(
    'tripways-ourairports-daily',
    '0 2 * * *',
    $cron$
      SELECT net.http_post(
        url := (
          SELECT secret.decrypted_secret
          FROM vault.decrypted_secrets AS secret
          WHERE secret.name = 'project_url'
        ) || '/functions/v1/ingestion-base-data',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (
            SELECT secret.decrypted_secret
            FROM vault.decrypted_secrets AS secret
            WHERE secret.name = 'ingestion_worker_secret'
          ),
          'Idempotency-Key', 'ourairports-' || to_char(CURRENT_DATE, 'YYYY-MM-DD')
        ),
        body := jsonb_build_object(
          'sourceCode', 'ourairports',
          'providerMode', 'ourairports'
        )
      );
    $cron$
  )
  INTO v_job_id;

  RETURN v_job_id;
END;
$$;

REVOKE ALL ON FUNCTION private.configure_ourairports_cron()
FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.configure_ourairports_cron() TO service_role;
