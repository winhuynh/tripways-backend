-- ============================================================================
-- Function: admin.configure_ingestion_crons
-- Purpose: Install and configure ingestion & cache schedules.
-- Responsibilities: Validate Vault and manage all ingestion jobs idempotently.
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
  v_project_url           TEXT;
  v_worker_secret         TEXT;
  v_aerodatabox_job       BIGINT;
  v_tp_warm_job           BIGINT;
  v_tp_day6_job           BIGINT;
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

  -- Unschedule existing jobs (including retired/on-demand ourairports jobs)
  PERFORM cron.unschedule(job.jobid)
  FROM cron.job AS job
  WHERE job.jobname IN (
    'tripways-ourairports-daily',
    'tripways-aerodatabox-monthly',
    'tripways-aerodatabox-weekly',
    'tripways-travelpayouts-top-warm',
    'tripways-travelpayouts-day6-smart-refresh'
  );

  -- Note: OurAirports base-data ingestion is on-demand (static master reference data).
  -- It is invoked manually via CLI (pnpm ourairports:import-local) or administrative trigger.

  -- 1. AeroDataBox Weekly Direct Routes Batch (Tầng 2 - Chủ Nhật lúc 03:00 UTC, 7 ngày 1 lần)
  SELECT cron.schedule(
    'tripways-aerodatabox-weekly',
    '0 3 * * 0',
    $cron$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/ingestion-routes',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'ingestion_worker_secret'),
          'Idempotency-Key', 'aerodatabox-' || to_char(CURRENT_DATE, 'IYYY-IW')
        ),
        body := jsonb_build_object('providerMode', 'aerodatabox', 'scope', 'top_hubs', 'limit', 80)
      );$cron$
  )
  INTO v_aerodatabox_job;

  -- 3. Travelpayouts Warm Top 200 Routes (Tầng 3 - 04:00 UTC mỗi 3 ngày)
  SELECT cron.schedule(
    'tripways-travelpayouts-top-warm',
    '0 4 */3 * *',
    $cron$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/flight-route-cache',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'ingestion_worker_secret')
        ),
        body := jsonb_build_object('mode', 'warm_top_routes')
      );$cron$
  )
  INTO v_tp_warm_job;

  -- 4. Travelpayouts Day 6 Active Demand Smart Refresh (Tầng 3 - 05:00 UTC hàng ngày)
  SELECT cron.schedule(
    'tripways-travelpayouts-day6-smart-refresh',
    '0 5 * * *',
    $cron$SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') || '/functions/v1/flight-route-cache',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'ingestion_worker_secret')
        ),
        body := jsonb_build_object('mode', 'day6_active_refresh')
      );$cron$
  )
  INTO v_tp_day6_job;

  RETURN jsonb_build_object(
    'aerodatabox_job_id', v_aerodatabox_job,
    'tp_warm_job_id', v_tp_warm_job,
    'tp_day6_job_id', v_tp_day6_job
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.configure_ingestion_crons()
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.configure_ingestion_crons() TO service_role;
