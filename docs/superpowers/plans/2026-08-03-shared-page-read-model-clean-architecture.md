# Shared Page Read Model and Clean Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace duplicated page/search logic with one shared route-search projection and four
page-specific, single-load read models while preserving correctness, source rights, and indexability.

**Architecture:** PostgreSQL materializes one canonical route-search projection and four independent
page read-model tables under one atomic publication version. TypeScript Edge boundaries share small
runtime contracts, one route-filter parser, one envelope validator, and one thin query handler.

**Tech Stack:** PostgreSQL 17, Supabase SQL/RPC/RLS, Deno TypeScript Edge Functions, SQL E2E tests,
`EXPLAIN (ANALYZE, BUFFERS)`.

---

### Task 1: Characterize all required page and search behavior

**Files:**

- Create: `supabase/functions/_shared/contracts/tests/page_contract_characterization.test.ts`
- Create: `supabase/snippets/e2e_shared_route_search_characterization.sql`
- Create: `supabase/snippets/e2e_page_read_model_characterization.sql`

- [ ] Write failing TypeScript tests that require one canonical page identity, route-filter, cursor,
      and envelope shape across Homepage, City, Airport, Route, and generic route discovery.
- [ ] Write failing SQL tests that require identical stops, airline, connection, duration, layover,
      cabin, currency, and price semantics for global, origin-city, origin-airport, and city-pair
      scopes.
- [ ] Write failing SQL tests requiring each page shell to return one bounded payload, one
      `data_version`, and the existing required page modules.
- [ ] Run focused tests and confirm failure is caused by missing shared contracts/read models.

Expected commands:

```bash
cd supabase/functions
deno test _shared/contracts/tests/page_contract_characterization.test.ts
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -f supabase/snippets/e2e_shared_route_search_characterization.sql
```

### Task 2: Add shared TypeScript boundary contracts

**Files:**

- Create: `supabase/functions/_shared/contracts/guards.ts`
- Create: `supabase/functions/_shared/contracts/primitives.ts`
- Create: `supabase/functions/_shared/contracts/route-filters.ts`
- Create: `supabase/functions/_shared/contracts/page-request.ts`
- Create: `supabase/functions/_shared/contracts/rpc-envelope.ts`
- Create: `supabase/functions/_shared/contracts/query-handler.ts`
- Create: `supabase/functions/_shared/contracts/tests/*.test.ts`
- Modify: page and route request/response/handler files under `supabase/functions/v1/`

- [ ] Test `isRecord`, slug, locale, IATA, airline, currency, bounded integer, non-negative decimal,
      unique code arrays, cursor, and unknown-field rejection.
- [ ] Implement small functions with no feature-specific business rules.
- [ ] Test and implement one canonical `RouteSearchRequest` parser:

```ts
type RouteSearchScope =
  | { type: "global" }
  | { type: "origin_city"; key: string }
  | { type: "origin_airport"; key: string }
  | { type: "city_pair"; from: string; to: string };

type RouteSearchFilters = {
  maxStops: 0 | 1 | 2 | 3;
  airlines: string[];
  connectionAirports: string[];
  maxDurationMinutes: number | null;
  maxLayoverMinutes: number | null;
  cabin: "any" | "economy" | "premium_economy" | "business" | "first";
  priceMax: number | null;
  currency: string | null;
};
```

- [ ] Test and implement one shared page request parser and one envelope validator.
- [ ] Test and implement one thin query handler accepting parser, RPC caller, response mapper, and
      stable feature error code.
- [ ] Migrate every real consumer, then delete duplicate local helpers.
- [ ] Run all Deno tests, format, lint, and typecheck.

### Task 3: Add publication versions and the canonical route-search projection

**Files:**

- Create: `supabase/sql_src/schema/pseo/publication_versions.sql`
- Create: `supabase/sql_src/schema/route_discovery/route_search_options.sql`
- Create: `supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql`
- Create: `supabase/sql_src/functions/route_discovery/parse_route_search_request.sql`
- Create: `supabase/sql_src/functions/route_discovery/search_route_options.sql`
- Create: `supabase/sql_src/functions/route_discovery/serialize_route_search_result.sql`
- Test: `supabase/snippets/e2e_shared_route_search.sql`

- [ ] Write failing table, constraint, RLS, grant, version, and cardinality tests.
- [ ] Add one relational row per searchable route option and publication version, including scope
      identities, ordered arrays, schedule, rank fields, route path, and display-safe price fields.
- [ ] Add composite scope/rank indexes, intentional GIN airline/connection indexes, and supporting
      foreign-key indexes.
- [ ] Test and implement one SQL parser that revalidates every shared filter and cursor.
- [ ] Test and implement one internal search function applying every filter once and returning rows,
      facets, next cursor, and total semantics from one filtered relation.
- [ ] Test and implement one route serializer for schedules, ordered connections/airlines, price
      state, and operational unknowns.
- [ ] Confirm every scope returns identical filter semantics and deterministic ranking.

### Task 4: Add four page-specific read-model tables

**Files:**

- Create: `supabase/sql_src/schema/pseo/homepage_read_models.sql`
- Create: `supabase/sql_src/schema/pseo/city_page_read_models.sql`
- Create: `supabase/sql_src/schema/pseo/airport_page_read_models.sql`
- Create: `supabase/sql_src/schema/pseo/route_page_read_models.sql`
- Test: `supabase/snippets/e2e_page_read_model_schema.sql`

- [ ] Write failing tests for native page identity, locale, version, current marker, bounded payload,
      canonical path, freshness, status, and indexability constraints.
- [ ] Add one focused table per page type with no universal nullable page schema.
- [ ] Add unique current-row lookup indexes ordered by native identity and locale.
- [ ] Enable RLS, revoke client access, and grant service-role-only reads/writes.
- [ ] Verify every foreign-key join has an intentional supporting index.

### Task 5: Build Homepage and City read models

**Files:**

- Create: `supabase/sql_src/functions/pseo/refresh_homepage_read_models.sql`
- Create: `supabase/sql_src/functions/pseo/refresh_city_page_read_models.sql`
- Rewrite: `supabase/sql_src/functions/pseo/rpc_get_homepage_discovery.sql`
- Rewrite: `supabase/sql_src/functions/pseo/rpc_get_city_page.sql`
- Rewrite: Homepage/City Edge query contracts under `supabase/functions/v1/`
- Test: `supabase/snippets/e2e_homepage_city_single_load.sql`

- [ ] Write failing tests requiring complete bounded Homepage and City payloads from one current
      read-model row.
- [ ] Materialize Homepage modules and an initial shared-search bootstrap result.
- [ ] Materialize City identity, airports, quick facts, cited facts, initial direct routes, price
      state, airlines, FAQs, and internal links.
- [ ] Rewrite each page-shell RPC to normalize identity and perform one indexed read-model lookup.
- [ ] Route all interactive Homepage and City filters through the shared route-search RPC.
- [ ] Delete superseded City route-map/direct-route filter implementations after characterization
      tests pass through the shared path.

### Task 6: Build Airport and Route Page read models

**Files:**

- Create: `supabase/sql_src/functions/pseo/refresh_airport_page_read_models.sql`
- Create: `supabase/sql_src/functions/pseo/refresh_route_page_read_models.sql`
- Rewrite: `supabase/sql_src/functions/pseo/rpc_get_airport_page.sql`
- Rewrite: `supabase/sql_src/functions/pseo/rpc_get_route_page.sql`
- Rewrite: Airport/Route Edge query contracts under `supabase/functions/v1/`
- Test: `supabase/snippets/e2e_airport_route_single_load.sql`

- [ ] Write failing tests requiring complete bounded Airport and Route payloads from one current
      read-model row.
- [ ] Materialize Airport identity, terminals, facilities, access, parking, lounges, notices,
      nearby airports, facts, initial routes, price state, FAQs, and links.
- [ ] Materialize Route identity, summaries, initial 0–3-stop options, price state, airport
      comparison, facts, editorial, FAQs, unknowns, and disclosure.
- [ ] Rewrite each page-shell RPC to one indexed lookup.
- [ ] Route all Airport and Route filters through the shared route-search RPC.
- [ ] Delete superseded page-specific search functions after shared contract tests pass.

### Task 7: Make refresh and publication atomic

**Files:**

- Rewrite: `supabase/sql_src/functions/pseo/refresh_pseo_read_models.sql`
- Create: `supabase/sql_src/functions/pseo/publish_read_model_version.sql`
- Modify: `supabase/seed/provider_ready_page_fixture.sql`
- Test: `supabase/snippets/e2e_atomic_read_model_publication.sql`

- [ ] Write a failing test proving a mid-refresh failure leaves the previous version current.
- [ ] Build route search and all affected page read models under one candidate version.
- [ ] Validate required row counts, lineage, freshness, content, and indexability before publication.
- [ ] Atomically flip the candidate version to current and retire the prior marker.
- [ ] Keep fixtures permanently noindex and make clean reset finish with 0–3-stop current models.

### Task 8: Audit and optimize query plans

**Files:**

- Create: `supabase/snippets/perf_page_read_models.sql`
- Create: `supabase/snippets/perf_shared_route_search.sql`
- Create: `supabase/seed/performance_scale_fixture.sql` only if isolated test generation cannot supply
  deterministic scale rows.
- Modify: relevant schema indexes identified by plans.

- [ ] Generate deterministic scale rows inside rollback-based performance snippets unless persistent
      scale fixtures are required for repeatability.
- [ ] Capture `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` for all four page lookups, all shared search
      scopes, representative filters, deep logical pagination, and sitemap.
- [ ] Remove sequential scans on scale-sensitive relations where selective indexed access is
      expected.
- [ ] Avoid redundant indexes and document why each GIN, composite, partial, or covering index
      exists.
- [ ] Report planning time, execution time, buffers, row estimates, and chosen indexes without
      encoding machine-specific timing assertions.

### Task 9: Remove obsolete code and complete clean-code review

**Files:**

- Delete: superseded page-specific request helpers, route filter SQL, serializers, and RPCs.
- Modify: `scripts/regenerate-supabase-migrations.sh`
- Modify: `supabase/config.toml`
- Modify: `package.json`
- Modify: `docs/features/pseo/README.md`
- Modify: `docs/features/route-discovery/README.md`

- [ ] Run `rg` duplication scans for route filters, price eligibility, route paths, operational
      unknowns, envelopes, record guards, code parsing, and pagination.
- [ ] Confirm every remaining shared helper has two or more consumers.
- [ ] Confirm every file has one responsibility and every SQL function follows repository headers,
      step comments, casing, and readable clause layout.
- [ ] Remove compatibility shims because the environment is local.
- [ ] Update provider switching, refresh, page-load, filtering, and performance documentation.
- [ ] Regenerate migrations exclusively from `supabase/sql_src`.

### Task 10: Full verification and handoff

**Files:**

- Verify all changed source, tests, generated migrations, and documentation.

- [ ] Run a clean local Supabase reset.
- [ ] Run every SQL functional, security, atomicity, and query-plan snippet sequentially.
- [ ] Run all Deno tests, format, lint, and typecheck.
- [ ] Run Prettier and `git diff --check`.
- [ ] Query for public tables without RLS and page/search RPC grants to `anon` or `authenticated`;
      both counts must be zero.
- [ ] Confirm each page-shell RPC reads one page-specific current row and returns one version.
- [ ] Confirm clean reset has route options and search projections for stop counts 0, 1, 2, and 3.
- [ ] Report `implemented`, `skipped`, and `add when`, including exact query-plan and test evidence.

No task automatically commits, pushes, deploys, or links remote resources because repository rules
require explicit user approval for those operations.
