-- ============================================================================
-- Function: admin.configure_ingestion_crons
-- Purpose: Install base ingestion and demand-only flight-cache refresh schedules.
-- Responsibilities: Validate Vault and replace both jobs idempotently.
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
  v_route_cache_job   BIGINT;
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
    'tripways-travelpayouts-demand-cache-daily'
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
    'tripways-travelpayouts-demand-cache-daily',
    '20 2 * * *',
    $cron$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/flight-route-cache',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'ingestion_worker_secret'),
          'User-Agent', 'Tripways-Cache-Refresh/1.0'
        ),
        body := jsonb_build_object(
          'origin', due.origin_iata,
          'destination', due.destination_iata,
          'market', due.market_code,
          'currency', due.currency_code,
          'locale', due.locale
        )
      )
      FROM (
        SELECT cache.*
        FROM admin.flight_route_cache_states AS cache
        WHERE cache.status = 'fresh'
          AND cache.last_requested_at > now() - INTERVAL '30 days'
          AND cache.refreshed_at <= now() - INTERVAL '6 days'
          AND cache.next_refresh_at <= now()
        ORDER BY cache.last_requested_at DESC
        LIMIT 50
      ) AS due;$cron$
  )
  INTO v_route_cache_job;

  RETURN jsonb_build_object(
    'ourairports_job_id', v_ourairports_job,
    'route_cache_job_id', v_route_cache_job
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.configure_ingestion_crons()
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.configure_ingestion_crons() TO service_role;
