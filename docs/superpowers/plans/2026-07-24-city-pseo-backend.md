# City pSEO Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Tripways Backend return a complete, filterable, preview-safe city pSEO payload for Bangkok from local Supabase.

**Architecture:** Existing country, city, airport, airline, route, and service tables remain the source of truth. New relational read models project direct routes at filterable grain, aggregate destination cards, store reviewed page content, register pSEO URLs, and store semantic internal-link edges. PostgreSQL owns refresh, filtering, facets, ranking, indexability metadata, and the shared response envelope.

**Tech Stack:** PostgreSQL 17, Supabase CLI, SQL source files, migration files, deterministic SQL seed fixtures, and rollback-based SQL verification.

---

## File map

- `supabase/sql_src/schema/public/city_direct_routes.sql`: filterable city direct-route projection.
- `supabase/sql_src/schema/public/city_destination_summaries.sql`: default destination-card projection.
- `supabase/sql_src/schema/public/pseo_pages.sql`: canonical URL and indexability registry.
- `supabase/sql_src/schema/public/city_pages.sql`: city page metadata, content, facts, and freshness.
- `supabase/sql_src/schema/public/city_page_faqs.sql`: ordered reviewed FAQs.
- `supabase/sql_src/schema/public/pseo_internal_links.sql`: semantic internal-link graph.
- `supabase/sql_src/functions/pseo/refresh_city_pseo_read_models.sql`: rebuild route projections and page counters.
- `supabase/sql_src/functions/pseo/rpc_get_city_page.sql`: return one bounded frontend page payload.
- `supabase/sql_src/functions/pseo/rpc_search_city_direct_routes.sql`: filter, facet, rank, and paginate direct destinations.
- `supabase/seed/city_pseo_fixture.sql`: development-only DMK/routes/content/FAQ/link preview fixture.
- `supabase/snippets/e2e_city_pseo.sql`: rollback-based RPC and indexability verification.
- `supabase/config.toml`: include the new seed file after the routing fixture.
- `supabase/migrations/<timestamp>_city_pseo_foundation.sql`: generated deployment migration containing the reviewed SQL sources.
- `docs/features/pseo/README.md`: responsibility, payload examples, local commands, and deferred scope.

### Task 1: Write the failing city pSEO contract

**Files:**

- Create: `supabase/snippets/e2e_city_pseo.sql`

- [ ] Write rollback-based assertions for `rpc_get_city_page`, city airport aggregation, destination totals, filter facets, filtered airport results, FAQ content, internal-link groups, shared envelope shape, and development-fixture `is_indexable = false`.
- [ ] Run:

```bash
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 \
  -f supabase/snippets/e2e_city_pseo.sql
```

Expected: fail because `public.rpc_get_city_page(JSONB)` does not exist.

### Task 2: Add focused relational schema files

**Files:**

- Create the six schema files listed in the file map.

- [ ] Define one table per source file with explicit foreign keys, checks, unique constraints, RLS, least-privilege grants, and readable indexes.
- [ ] Keep `city_direct_routes` at route + airport + airline grain so airport, airline, country, duration, and departure filters use scalar indexed columns.
- [ ] Keep `city_destination_summaries` at origin-city + destination-city + data-version grain.
- [ ] Keep SEO/editorial lifecycle outside `public.cities`.
- [ ] Ensure all exposed tables revoke `anon` and `authenticated` access and grant service-role access only.

### Task 3: Add refresh behavior

**Files:**

- Create: `supabase/sql_src/functions/pseo/refresh_city_pseo_read_models.sql`

- [ ] Implement a function that:
  1. Creates one new `data_version`.
  2. Rebuilds direct-route rows only from active airports, accepted route statuses, valid services, and active airlines.
  3. Aggregates city destination summaries.
  4. Updates city page route counters and freshness.
  5. Returns `{ data, meta, error }`.
- [ ] Preserve unknown frequency and seasonality rather than converting missing values to favorable values.
- [ ] Set an explicit empty `search_path` and schema-qualify all objects.

### Task 4: Add frontend RPC contracts

**Files:**

- Create: `supabase/sql_src/functions/pseo/rpc_get_city_page.sql`
- Create: `supabase/sql_src/functions/pseo/rpc_search_city_direct_routes.sql`

- [ ] Implement `rpc_get_city_page(JSONB)` for `city_slug`, `locale`, and bounded `destination_limit`.
- [ ] Return city, country, page metadata, airports, quick facts, featured destinations, airline facets, direct countries, FAQs, and grouped internal links.
- [ ] Implement `rpc_search_city_direct_routes(JSONB)` with bounded airport, airline, country, duration, departure-window, limit, and offset filters.
- [ ] Calculate results and facets from the same filtered set.
- [ ] Return stable `ERR_INVALID_REQUEST`, `ERR_CITY_NOT_FOUND`, and `ERR_CITY_PAGE_NOT_FOUND` errors without raw database details.
- [ ] Re-run the SQL contract after loading schema/functions manually; expected failure moves from missing RPC to missing fixture page data.

### Task 5: Add deterministic Bangkok preview seed

**Files:**

- Create: `supabase/seed/city_pseo_fixture.sql`
- Modify: `supabase/config.toml`

- [ ] Add DMK, one additional development airline, direct Bangkok fixture routes/services, and reviewed placeholder English content under the existing development-only source.
- [ ] Seed pSEO page registry rows, a Bangkok city page, FAQs, and internal-link targets/edges with fixed UUIDs.
- [ ] Keep every fixture page `is_indexable = false` with `noindex_reason = development_fixture`.
- [ ] Call the refresh function at the end of the seed so the frontend payload is immediately available after reset.
- [ ] Add the seed path after `flight_routing_fixture.sql`.

### Task 6: Generate migration and rebuild local Supabase

**Files:**

- Create: `supabase/migrations/<timestamp>_city_pseo_foundation.sql`

- [ ] Create the migration with:

```bash
supabase migration new city_pseo_foundation
```

- [ ] Assemble the six schema files and three function files into the migration in dependency order.
- [ ] Run:

```bash
supabase db reset --local --yes
```

Expected: migrations and all three seed files apply successfully.

- [ ] Run the city pSEO contract. Expected: all assertions pass and the transaction rolls back.
- [ ] Run the existing Route Discovery E2E snippet. Expected: existing assertions continue to pass.

### Task 7: Document and verify the feature

**Files:**

- Create: `docs/features/pseo/README.md`

- [ ] Document ownership, data flow, RPC examples, preview content status, frontend consumption, local reset/test commands, and deferred scope.
- [ ] Run:

```bash
pnpm format:check
deno fmt --config supabase/functions/deno.json --check supabase/functions
deno check --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query/index.ts
git diff --check
```

- [ ] Query both RPCs through Postgres and confirm the Bangkok payload contains multiple airports, destinations, airlines, countries, FAQs, internal-link groups, canonical metadata, `data_version`, and `is_indexable = false`.
- [ ] Do not commit, push, deploy, or change the web frontend.
