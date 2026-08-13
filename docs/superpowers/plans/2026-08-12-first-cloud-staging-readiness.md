# First Cloud Staging Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the backend safe and operationally complete for its first cloud staging deployment with real provider data and database-enforced noindex.

**Architecture:** Canonical ingestion is independent from publication. A valid route-price refresh synchronizes staging pSEO source pages and atomically publishes the read models; server configuration selects the environment. One cron installer and one readiness script own staging operations.

**Tech Stack:** PostgreSQL 17, Supabase RLS/Edge Functions/Cron/Vault, Deno TypeScript, shell and SQL verification.

---

### Task 1: Add the staging publication lifecycle

**Files:**

- Modify: `supabase/sql_src/schema/pseo/shared/publication_versions.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/publish_read_model_version.sql`

- [ ] Add `staging` to the constrained source types.
- [ ] Force staging pages to `noindex` with `staging_environment`.
- [ ] Preserve production-only indexability gates.

### Task 2: Separate canonical ingestion and make price publication safe

**Files:**

- Modify: `supabase/sql_src/functions/ingestion/publish_base_data_batch.sql`
- Modify: `supabase/sql_src/functions/ingestion/publish_price_estimate_batch.sql`
- Modify: `supabase/functions/v1/ingestion/price-estimates/index.ts`
- Modify: `supabase/functions/v1/ingestion/price-estimates/service.ts`

- [ ] Stop base-data ingestion from requiring a route/page publication.
- [ ] Resolve usable route-price rows before deleting the current cache.
- [ ] Preserve the cache and fail when zero rows are usable.
- [ ] Replace prices, synchronize source pages, publish the configured environment, and return `dataVersion` atomically.
- [ ] Prune expired receipt metadata according to source retention.

### Task 3: Consolidate pSEO synchronization and cron operations

**Files:**

- Replace: `supabase/sql_src/operations/generate_local_geo_preview_pages.sql`
- Create: `supabase/sql_src/operations/sync_provider_pseo_pages.sql`
- Delete: `supabase/sql_src/operations/configure_ourairports_cron.sql`
- Delete: `supabase/sql_src/operations/configure_travelpayouts_content_cron.sql`
- Create: `supabase/sql_src/operations/configure_ingestion_crons.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] Generalize source-page upserts for development fixture and staging.
- [ ] Generate route pages only from fresh route prices.
- [ ] Validate Vault prerequisites and install both cron jobs idempotently through one function.

### Task 4: Remove unused schemas, SQL functions, and Edge code

**Files:**

- Delete: empty analytics schema source.
- Delete: unused homepage-origin Edge/RPC, place-search RPC, route-price resolver, and identity helpers.
- Modify: `supabase/config.toml`
- Modify: `package.json`
- Modify: `supabase/sql_src/functions/pseo/shared/rpc_get_flight_affiliate_handoff.sql`
- Modify: affiliate-handoff Edge files.

- [ ] Remove all generator/config/test references to deleted objects.
- [ ] Restrict affiliate RPC execution to `service_role`.
- [ ] Apply bounded in-memory abuse protection at the public affiliate Edge.
- [ ] Include every deployed Edge entrypoint in type checking.

### Task 5: Add staging readiness verification and synchronize docs/contracts

**Files:**

- Create: `scripts/check-staging-readiness.sh`
- Modify: SQL contract tests, E2E snippets, `.env.example`, and technical roadmap.

- [ ] Verify Vault names, cron jobs, current staging publication, noindex state, RLS, and grants.
- [ ] Update existing contracts for the consolidated runtime surface.
- [ ] Document the exact first staging bootstrap order.

### Task 6: Rebuild and verify

- [ ] Regenerate migrations from `supabase/sql_src`.
- [ ] Reset Supabase local from zero.
- [ ] Run Deno format, type checks, unit tests, SQL contracts, and relevant E2E snippets.
- [ ] Prove zero-accepted price publication preserves cache and a valid batch publishes a staging version.
- [ ] Prove staging sitemap is empty and affiliate RPC is not client-executable.
- [ ] Run secret scan and `git diff --check`.

No commit or remote deployment is authorized by this plan.
