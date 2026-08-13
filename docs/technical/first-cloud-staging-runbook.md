# First Cloud Staging Runbook

## Required Edge secrets

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `INGESTION_WORKER_SECRET`
- `PUBLICATION_SOURCE_TYPE=staging`
- `TRAVELPAYOUTS_TOKEN`
- `TRAVELPAYOUTS_ORIGINS`
- Travelpayouts currency, market, and locale settings

Staging must never reuse production credentials.

## Bootstrap order

1. Deploy the clean migrations and all configured Edge Functions.
2. Add Vault secrets `project_url` and `ingestion_worker_secret`.
3. Configure Edge secrets with `PUBLICATION_SOURCE_TYPE=staging`.
4. Call `admin.configure_ingestion_crons()` once with service-role database access.
5. Trigger `ingestion-base-data` for OurAirports and wait for canonical publication.
6. Trigger `ingestion-price-estimates` for Travelpayouts. This synchronizes pSEO source pages and
   publishes the first current staging read model.
7. Run `STAGING_DATABASE_URL=... pnpm check:staging`.
8. Smoke-test page, route-search, homepage-statistics, sitemap, and affiliate-handoff endpoints.

## Required result

- The current publication has `source_type = 'staging'`.
- Every pSEO page has `is_indexable = FALSE` and `noindex_reason = 'staging_environment'`.
- Sitemap returns no URLs.
- Both provider cron jobs are active.
- No fixture publication is current.
- `anon` and `authenticated` cannot call the affiliate database RPC directly.
