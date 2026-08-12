# Lean Flight and pSEO Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the over-normalized fixture-era schema with canonical reference tables, three lean flight tables, three aggregate page source tables, and three immutable page read models.

**Architecture:** Rewrite SQL source-of-truth and fixtures as a clean baseline rather than adding compatibility views. Page-owned editorial content moves to validated JSONB, while shared reference and current flight observations stay relational and service-role-only.

**Tech Stack:** PostgreSQL 17, Supabase RLS, PL/pgSQL, JSONB, Deno/TypeScript contract tests, generated baseline migrations.

---

### Task 1: Lock the lean schema contract

**Files:**

- Modify: `supabase/functions/_shared/security/tests/flight_routing_schema_sql_contract.test.ts`
- Modify: `supabase/functions/_shared/security/tests/provider_ready_schema_sql_contract.test.ts`
- Modify: `supabase/functions/_shared/security/tests/route_discovery_sql_contract.test.ts`
- Modify: `supabase/functions/_shared/security/tests/canonical_pseo_sql_contract.test.ts`

- [ ] Assert removed table source files no longer exist.
- [ ] Assert cities expose `iata_code`, `currency_code`, and `primary_language`.
- [ ] Assert observations preserve provider IATA plus nullable canonical airline ID.
- [ ] Assert route options contain `observed_amount` and no schedule/range fields.
- [ ] Assert page source tables own `content JSONB` and read-model tables remain separate.
- [ ] Run focused contract tests and observe failures against the old schema.

### Task 2: Simplify canonical reference and flight schema

**Files:**

- Modify: `supabase/sql_src/schema/flight_routing/cities.sql`
- Modify: `supabase/sql_src/schema/flight_routing/flight_routes.sql`
- Create: `supabase/sql_src/schema/flight_routing/flight_content_observations.sql`
- Create: `supabase/sql_src/schema/route_discovery/flight_route_options.sql`
- Delete: obsolete metro, terminal, nearby, service, price-estimate, and route-option sources.
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] Add canonical city fields with bounded checks and indexes.
- [ ] Reduce flight routes to evidence-only fields.
- [ ] Implement 24-hour observations with provider/canonical airline separation.
- [ ] Implement direct-route publication projection with observed amount.
- [ ] Remove obsolete SQL sources from migration generation.
- [ ] Run schema contract tests until green.

### Task 3: Consolidate page source content

**Files:**

- Modify: `supabase/sql_src/schema/pseo/city/city_pages.sql`
- Modify: `supabase/sql_src/schema/pseo/airport/airport_pages.sql`
- Modify: `supabase/sql_src/schema/pseo/route/route_pages.sql`
- Delete: page-owned child content schemas.
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] Add non-null object-shaped `content JSONB` with expected top-level module checks.
- [ ] Remove child content sources and generator entries.
- [ ] Keep all three read-model schemas unchanged and separately protected.
- [ ] Run page schema contracts until green.

### Task 4: Rewire publication, search, and ingestion

**Files:**

- Modify: `supabase/sql_src/functions/ingestion/publish_price_estimate_batch.sql`
- Modify: `supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql`
- Modify: `supabase/sql_src/functions/route_discovery/rpc_search_routes.sql`
- Modify: page payload builders and affiliate handoff RPC.
- Modify: `supabase/sql_src/operations/configure_travelpayouts_content_cron.sql`

- [ ] Publish into `flight_content_observations` and preserve provider airline IATA.
- [ ] Build direct `flight_route_options` without schedule or connecting-path synthesis.
- [ ] Read page modules from aggregate content.
- [ ] Expose only `observed_amount`, currency, freshness, and expiry publicly.
- [ ] Run focused SQL contract tests until green.

### Task 5: Rewrite fixtures and E2E contracts

**Files:**

- Modify: `supabase/seed/*.sql`
- Modify: `supabase/snippets/*.sql` that reference removed tables/columns.

- [ ] Rewrite reference and pSEO fixture inserts for aggregate content.
- [ ] Replace service-based route fixtures with direct route evidence.
- [ ] Update observation and route-search E2E expectations.
- [ ] Confirm unresolved airlines retain provider IATA while canonical ID remains null.

### Task 6: Regenerate and verify

**Files:**

- Regenerate: `supabase/migrations/*.sql`
- Modify: relevant feature/roadmap documentation.

- [ ] Regenerate migrations and confirm every SQL source appears exactly once.
- [ ] Reset local Supabase from empty state and seed successfully.
- [ ] Run ingestion, pSEO, flight-routing, route-discovery, and Edge checks.
- [ ] Run focused SQL E2E snippets.
- [ ] Run `git diff --check` and verify unrelated user changes remain intact.
- [ ] Do not commit, push, deploy, configure remote secrets, or activate remote cron.
