#!/usr/bin/env bash
set -euo pipefail

staging_database_url="${STAGING_DATABASE_URL:?Set STAGING_DATABASE_URL to the cloud staging database connection string.}"

psql "$staging_database_url" -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'admin')
    OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('private', 'analytics'))
  THEN
    RAISE EXCEPTION 'ERR_STAGING_SCHEMA_STATE';
  END IF;

  IF (SELECT count(*) FROM vault.decrypted_secrets
      WHERE name IN ('project_url', 'ingestion_worker_secret')) <> 2
  THEN
    RAISE EXCEPTION 'ERR_STAGING_VAULT_INCOMPLETE';
  END IF;

  IF (SELECT count(*) FROM cron.job
      WHERE active
        AND jobname IN (
          'tripways-ourairports-daily',
          'tripways-travelpayouts-demand-cache-daily'
        )) <> 2
  THEN
    RAISE EXCEPTION 'ERR_STAGING_CRON_INCOMPLETE';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.publication_versions
    WHERE is_current AND status = 'published' AND source_type = 'staging'
  ) OR EXISTS (
    SELECT 1 FROM public.publication_versions
    WHERE is_current AND source_type = 'development_fixture'
  )
  THEN
    RAISE EXCEPTION 'ERR_STAGING_PUBLICATION_INVALID';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pseo_pages
    WHERE is_indexable OR noindex_reason IS DISTINCT FROM 'staging_environment'
  )
  THEN
    RAISE EXCEPTION 'ERR_STAGING_INDEXABILITY_INVALID';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.role_table_grants
    WHERE grantee IN ('anon', 'authenticated')
      AND table_schema = 'admin'
  ) OR has_function_privilege(
    'anon',
    'public.rpc_get_flight_affiliate_handoff(uuid)',
    'EXECUTE'
  )
  THEN
    RAISE EXCEPTION 'ERR_STAGING_PRIVILEGE_INVALID';
  END IF;
END;
$$;

SELECT jsonb_build_object(
  'status', 'ready',
  'current_publication', (
    SELECT id FROM public.publication_versions WHERE is_current
  ),
  'route_prices', (SELECT count(*) FROM public.flight_route_prices),
  'route_options', (SELECT count(*) FROM public.flight_route_options),
  'pseo_pages', (SELECT count(*) FROM public.pseo_pages),
  'cron_jobs', (SELECT count(*) FROM cron.job WHERE active)
) AS staging_readiness;
SQL
