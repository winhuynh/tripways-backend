-- ============================================================================
-- Function: admin.configure_ingestion_crons
-- Purpose: Install the complete provider-ingestion schedule after Vault bootstrap.
-- Responsibilities: Validate prerequisites and replace both jobs idempotently.
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
  v_travelpayouts_job BIGINT;
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
    'tripways-ourairports-daily',
    'tripways-travelpayouts-content-daily-check'
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

  SELECT cron.schedule(
    'tripways-travelpayouts-content-daily-check',
    '20 2 * * *',
    $cron$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/ingestion-price-estimates',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'ingestion_worker_secret'),
          'Idempotency-Key', 'travelpayouts-content-' || to_char(CURRENT_DATE, 'YYYY-MM-DD')
        ),
        body := jsonb_build_object('sourceCode', 'travelpayouts', 'providerKey', 'travelpayouts')
      )
      WHERE NOT EXISTS (
        SELECT 1
        FROM public.flight_route_prices AS price
        JOIN admin.data_sources AS source ON source.id = price.source_id
        WHERE source.code = 'travelpayouts'
          AND price.status = 'published'
          AND price.valid_until > now()
          AND price.observed_at > now() - interval '6 days'
      );$cron$
  )
  INTO v_travelpayouts_job;

  RETURN jsonb_build_object(
    'ourairports_job_id', v_ourairports_job,
    'travelpayouts_job_id', v_travelpayouts_job
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.configure_ingestion_crons()
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.configure_ingestion_crons() TO service_role;
