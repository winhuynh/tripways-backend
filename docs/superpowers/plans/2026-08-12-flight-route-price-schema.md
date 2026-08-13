# Flight Route Price Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the unused canonical route-evidence table and make short-lived Travelpayouts prices explicit in `public.flight_route_prices`.

**Architecture:** `route_pages` owns pSEO route identity, `flight_route_options` remains the replaceable search read model, and `flight_route_prices` stores seven-day provider prices. The existing ingestion and frontend contracts remain provider-neutral while every stored price records `data_source = 'travelpayouts'`.

**Tech Stack:** PostgreSQL, Supabase migrations/RLS, PL/pgSQL, Deno contract tests, Next.js API contracts.

---

### Task 1: Replace the route evidence and observation schemas

**Files:**

- Delete: `supabase/sql_src/schema/flight_routing/flight_routes.sql`
- Rename: `supabase/sql_src/schema/flight_routing/flight_content_observations.sql`
- Create: `supabase/sql_src/schema/flight_routing/flight_route_prices.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] Delete the unused `public.flight_routes` source and remove it from migration generation.
- [ ] Rename the observation table and every constraint/index to `flight_route_prices`.
- [ ] Add `data_source TEXT NOT NULL` with a provider-code format constraint.
- [ ] Preserve seven-day validity, RLS, and service-role-only grants.

### Task 2: Update writes and reads

**Files:**

- Modify: `supabase/sql_src/functions/ingestion/publish_price_estimate_batch.sql`
- Modify: `supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql`
- Modify: `supabase/sql_src/functions/pseo/route/build_route_page_payload.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/resolve_route_price_estimate.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/rpc_get_flight_affiliate_handoff.sql`
- Modify: `supabase/sql_src/operations/configure_travelpayouts_content_cron.sql`

- [ ] Replace every observation-table reference with `public.flight_route_prices`.
- [ ] Set `data_source` from `admin.data_sources.provider_code` during publication, producing `travelpayouts` for the active source.
- [ ] Remove `public.flight_routes` from route-option refresh and derive options only from fresh published prices.
- [ ] Preserve opaque observation IDs and server-side affiliate handoff.

### Task 3: Synchronize verification and documentation

**Files:**

- Modify: `supabase/functions/_shared/security/tests/*sql_contract.test.ts`
- Modify: `supabase/snippets/test_flight_routing_schema.sql`
- Modify: relevant `docs/technical/*.md`

- [ ] Remove stale assertions and fixtures for `public.flight_routes`.
- [ ] Rename existing observation expectations to `public.flight_route_prices` and assert the `data_source` column.
- [ ] Update technical documentation to describe route pages, route options, and cached prices separately.

### Task 4: Regenerate and verify

**Files:**

- Regenerate: `supabase/migrations/*.sql`

- [ ] Run `bash scripts/regenerate-supabase-migrations.sh`; expect deterministic generation success.
- [ ] Run relevant Deno SQL contracts and ingestion tests; expect zero failures.
- [ ] Run `pnpm supabase:reset`; expect all migrations and seeds to apply.
- [ ] Query `information_schema`: expect `flight_route_prices` present and both old tables absent.
- [ ] Query grants and constraints: expect no direct `anon`/`authenticated` access and seven-day TTL enforcement.
- [ ] Run `git diff --check`; expect no whitespace errors.

No commit step is included because repository rules require explicit user authorization before committing.
