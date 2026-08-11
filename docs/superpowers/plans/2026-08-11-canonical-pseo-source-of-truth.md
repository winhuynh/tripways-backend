# Canonical pSEO Source of Truth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make page payloads and route search/filter read one versioned canonical route projection and one canonical pSEO registry.

**Architecture:** `flight_routes` and `flight_services` remain normalized truth. `route_search_options`, keyed by `publication_version_id`, is the only derived route projection; all pSEO page builders and search RPCs read that same version. `pseo_pages` owns canonical identity and publication lifecycle, while subtype tables own editorial content only.

**Tech Stack:** PostgreSQL 15, PL/pgSQL, Supabase migrations/RPC, Deno contract tests, psql E2E.

---

### Task 1: Lock canonical source contracts

**Files:**
- Modify: `supabase/functions/_shared/security/tests/canonical_pseo_sql_contract.test.ts`
- Modify: `supabase/functions/_shared/security/tests/route_discovery_sql_contract.test.ts`
- Create: `supabase/snippets/e2e_canonical_pseo_source.sql`

- [ ] Write failing source-contract tests that reject `pseo_direct_routes`, `city_destination_summaries`, `route_options`, duplicate page lifecycle fields, and slug-only city resolution.
- [ ] Run the focused Deno tests and observe the intended failures.

### Task 2: Consolidate schema ownership

**Files:**
- Modify: `supabase/sql_src/schema/pseo/shared/pseo_pages.sql`
- Modify: `supabase/sql_src/schema/pseo/city/city_pages.sql`
- Modify: `supabase/sql_src/schema/pseo/airport/airport_pages.sql`
- Modify: `supabase/sql_src/schema/pseo/route/route_pages.sql`
- Delete: `supabase/sql_src/schema/pseo/shared/pseo_direct_routes.sql`
- Delete: `supabase/sql_src/schema/pseo/city/city_destination_summaries.sql`
- Delete: `supabase/sql_src/schema/route_discovery/route_options.sql`

- [ ] Remove duplicated lifecycle, facts, and data-version columns from subtype page tables.
- [ ] Keep canonical path/status/indexability/freshness only in `pseo_pages`.
- [ ] Keep route projection facts only in `route_search_options` under a publication version.
- [ ] Run schema contract tests until green.

### Task 3: Build one publication pipeline

**Files:**
- Modify: `supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/publish_read_model_version.sql`
- Delete: `supabase/sql_src/functions/pseo/shared/refresh_pseo_read_models.sql`
- Delete: `supabase/sql_src/functions/route_discovery/refresh_route_options.sql`

- [ ] Add failing SQL E2E assertions that all published page/search rows use one version.
- [ ] Build `route_search_options` directly from normalized routes/services with one eligibility policy.
- [ ] Derive page eligibility and page read models inside the same candidate publication transaction.
- [ ] Verify atomic failure preserves the prior current publication.

### Task 4: Move every page builder to the canonical projection

**Files:**
- Modify: `supabase/sql_src/functions/pseo/city/resolve_city_page_context.sql`
- Modify: `supabase/sql_src/functions/pseo/city/build_city_page_payload.sql`
- Modify: `supabase/sql_src/functions/pseo/airport/build_airport_page_payload.sql`
- Modify: `supabase/sql_src/functions/pseo/route/build_route_page_payload.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/refresh_page_read_models.sql`
- Delete: `supabase/sql_src/functions/pseo/city/get_city_airport_route_stats.sql`
- Delete: `supabase/sql_src/functions/pseo/city/get_city_quick_facts.sql`
- Delete: `supabase/sql_src/functions/pseo/city/get_city_route_map.sql`

- [ ] Resolve city pages through canonical page slug and registry identity.
- [ ] Replace every read of legacy pSEO route projections with `route_search_options` for the candidate version.
- [ ] Resolve all route links from `pseo_pages.canonical_path` and omit targets absent from the candidate publication.
- [ ] Run page characterization E2E and contract tests.

### Task 5: Make search/filter consume the same projection

**Files:**
- Modify: `supabase/sql_src/functions/route_discovery/rpc_search_routes.sql`
- Modify: `supabase/sql_src/functions/pseo/homepage/refresh_homepage_statistics.sql`
- Modify: `supabase/sql_src/functions/pseo/homepage/rpc_search_places.sql`

- [ ] Assert search results, filter facets, homepage statistics, and page route facts share the current publication ID.
- [ ] Remove fallback queries to legacy route/page facts.
- [ ] Run route-search SQL and Edge contract tests.

### Task 6: Reproducible ingestion, seed, and migrations

**Files:**
- Modify: `supabase/sql_src/functions/ingestion/publish_base_data_batch.sql`
- Move local preview generation from `supabase/sql_src/operations/` to `supabase/seed/` or `scripts/`.
- Modify: `scripts/regenerate-supabase-migrations.sh`
- Regenerate: `supabase/migrations/*.sql`

- [ ] Ensure successful canonical ingestion invokes the single publisher or records a deterministic publish failure.
- [ ] Ensure every `sql_src` file appears exactly once in generated migrations.
- [ ] Reset local Supabase, import OurAirports, seed preview content, and publish one current version.

### Task 7: Full verification and frontend QA

**Files:**
- Verify backend and `/Users/winn/Documents/Tripways/tripways-web` without unrelated edits.

- [ ] Run backend formatting, Deno checks/tests, SQL E2E, migration regeneration guard, and database reset.
- [ ] Verify zero lifecycle drift, zero ambiguous page resolution, zero dangling internal links, and one current publication version.
- [ ] Run frontend lint, typecheck, tests, and production build.
- [ ] Browser-QA City, Airport, Route, slug rename, old-slug 404, and search filters against the same current publication.
