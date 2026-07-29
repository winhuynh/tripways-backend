# Airport pSEO Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build inbound/outbound airport pSEO read models and focused airport guidance content on one shared route projection while extending city pages with directional identity.

**Architecture:** Rename the existing city-specific route projection to a neutral pSEO projection and make both city and airport RPCs read it directly. Keep normalized route tables authoritative, reviewed airport guidance in focused pSEO tables, and one refresh function responsible for route eligibility, versioned facts, and indexability.

**Tech Stack:** PostgreSQL 17, Supabase CLI, PL/pgSQL, deterministic SQL-source migration generation, rollback-based SQL contracts.

---

### Task 1: Define failing shared-route and directional-city contracts

**Files:**

- Modify: `supabase/snippets/e2e_city_pseo.sql`
- Create: `supabase/snippets/e2e_airport_pseo.sql`

- [ ] **Step 1: Add a failing city direction contract**

Add rollback-based assertions that create outbound and inbound `city_pages` rows for the same city
and locale, resolve them with `route_direction`, and require
`direct_counterpart_city_count`/`direct_counterpart_country_count`.

- [ ] **Step 2: Add the airport contract skeleton**

Create `e2e_airport_pseo.sql` with transaction-local BKK airport-page content and assertions for:

```text
airport identity
outbound and inbound featured routes
published access, lounge, parking, notice, and FAQ content
outbound/inbound search filters and facets
development-source noindex
invalid IATA and missing-page errors
anon/authenticated privilege denial
```

- [ ] **Step 3: Observe the intended failure**

Run:

```bash
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 \
  -f supabase/snippets/e2e_airport_pseo.sql
```

Expected: failure because `airport_pages` and airport RPCs do not exist.

### Task 2: Generalize the shared route projection

**Files:**

- Move: `supabase/sql_src/schema/pseo/city_direct_routes.sql` → `supabase/sql_src/schema/pseo/pseo_direct_routes.sql`
- Modify: `supabase/sql_src/functions/pseo/refresh_city_pseo_read_models.sql`
- Modify: every pSEO SQL function referencing `public.city_direct_routes`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] **Step 1: Rename the table definition and add symmetric country identity**

Define `public.pseo_direct_routes` with the existing route-grain columns plus:

```sql
origin_country_id UUID NOT NULL REFERENCES public.countries (id)
```

Keep `UNIQUE (data_version, flight_route_id)`, route/frequency/duration/seasonality/confidence
checks, RLS, and service-role-only grants.

- [ ] **Step 2: Replace city-only indexes with shared access indexes**

Add btree indexes for origin/destination city, airport, airline, country, and outbound duration,
always including `data_version` immediately after the selected entity ID.

- [ ] **Step 3: Update all pSEO readers**

Mechanically replace `public.city_direct_routes` with `public.pseo_direct_routes` and rename local
aliases only where the old name obscures direction-neutral logic. Do not change public JSON keys in
this step.

- [ ] **Step 4: Update the refresh insert**

Populate `origin_country_id` from `origin_airport.country_id` and keep the current eligibility
predicate as the only route eligibility definition.

- [ ] **Step 5: Update deterministic migration ordering**

Replace the old schema filename with `pseo_direct_routes.sql` in the generator and preserve
dependency order before summary tables and functions.

- [ ] **Step 6: Verify existing contracts**

Run:

```bash
pnpm supabase:migrations:regenerate
pnpm supabase:reset
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 \
  -f supabase/snippets/e2e_city_pseo.sql
```

Expected: existing city pSEO contract passes before directional additions are enabled.

### Task 3: Add directional city-page identity and facts

**Files:**

- Modify: `supabase/sql_src/schema/pseo/city_pages.sql`
- Modify: `supabase/sql_src/functions/pseo/parse_city_page_identity.sql`
- Modify: `supabase/sql_src/functions/pseo/resolve_city_page_context.sql`
- Modify: city pSEO public RPCs under `supabase/sql_src/functions/pseo/`
- Modify: shared pSEO refresh function
- Modify: `supabase/seed/city_pseo_fixture.sql`

- [ ] **Step 1: Extend the city page schema**

Add:

```sql
route_direction TEXT NOT NULL DEFAULT 'outbound'
```

Constrain it to `outbound` or `inbound`; change city/slug uniqueness to include direction; rename
cached columns to:

```text
direct_counterpart_city_count
direct_counterpart_country_count
```

- [ ] **Step 2: Parse and resolve direction**

Default missing `route_direction` to `outbound`, validate the two allowed values, resolve the page
by `(city_id, locale, route_direction)`, and return the direction in context.

- [ ] **Step 3: Make city facts direction-aware**

For outbound pages use `origin_city_id`; for inbound pages use `destination_city_id`. Derive
counterpart city/country counts, airlines, durations, freshness, and source-rights eligibility from
the corresponding side of `pseo_direct_routes`.

- [ ] **Step 4: Make city route RPCs direction-aware**

Use the resolved direction to swap selected origin/destination identities without duplicating the
eligibility or filter query. Preserve the current outbound response when direction is omitted.

- [ ] **Step 5: Keep the fixture explicitly outbound**

Set seeded city page and registry identity to `bangkok:outbound`; do not create an indexable inbound
fixture.

- [ ] **Step 6: Run the directional city contract**

Regenerate/reset and run `e2e_city_pseo.sql`. Expected: both direction rows coexist and existing
outbound payload assertions still pass.

### Task 4: Add focused airport pSEO schema

**Files:**

- Create: `supabase/sql_src/schema/pseo/airport_pages.sql`
- Create: `supabase/sql_src/schema/pseo/airport_access_options.sql`
- Create: `supabase/sql_src/schema/pseo/airport_lounges.sql`
- Create: `supabase/sql_src/schema/pseo/airport_parking_information.sql`
- Create: `supabase/sql_src/schema/pseo/airport_page_notices.sql`
- Create: `supabase/sql_src/schema/pseo/airport_page_faqs.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] **Step 1: Add `airport_pages`**

Implement the exact identity, reviewed SEO fields, route facts, lifecycle fields, constraints,
indexes, RLS, revokes, and service-role grants from the approved design. Use one row per
`(airport_id, locale)`.

- [ ] **Step 2: Add access options**

Implement bounded transport types, nullable consistent duration/price pairs, required primary
source URL and verification time, stable order, publication status, and page/status/order index.

- [ ] **Step 3: Add lounges**

Implement location type, constrained amenity array, source/freshness fields, ordering, publication
state, RLS, and service-role grants.

- [ ] **Step 4: Add parking information**

Implement one row per airport page, nullable booleans for unknown facts, required source/freshness,
and publication state. Do not add tariff rows.

- [ ] **Step 5: Add notices and FAQs**

Implement the reviewed schemas and existing city-FAQ conventions without introducing a
polymorphic content table.

- [ ] **Step 6: Register schema order**

Add the six tables after `pseo_pages` and `airport_pages` before its child tables in the migration
generator.

- [ ] **Step 7: Regenerate and verify schema guards**

Run migration regeneration, reset, migration-source coverage, RLS/privilege checks, and
`git diff --check`. Expected: clean rebuild and no exposed-table grants.

### Task 5: Add airport identity helpers

**Files:**

- Create: `supabase/sql_src/functions/pseo/parse_airport_page_identity.sql`
- Create: `supabase/sql_src/functions/pseo/resolve_airport_page_context.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] **Step 1: Test invalid and missing identities**

Add assertions for non-object input, invalid IATA, normalized lowercase IATA, missing airport, and
missing localized airport page.

- [ ] **Step 2: Implement the parser**

Normalize `airport_iata` with `upper(btrim(...))`, validate `^[A-Z]{3}$`, apply the existing locale
contract, and return `ERR_INVALID_REQUEST` through the shared envelope shape.

- [ ] **Step 3: Implement the resolver**

Resolve active/known airport identity, airport page, pSEO page, city, country, and `data_version`
without adding a view. Return `ERR_AIRPORT_NOT_FOUND` or `ERR_AIRPORT_PAGE_NOT_FOUND`.

- [ ] **Step 4: Verify helper contracts**

Run `e2e_airport_pseo.sql`. Expected: helper assertions pass and the script next fails at the
missing public RPC.

### Task 6: Replace refresh orchestration and derive airport facts

**Files:**

- Move: `supabase/sql_src/functions/pseo/refresh_city_pseo_read_models.sql` → `supabase/sql_src/functions/pseo/refresh_pseo_read_models.sql`
- Optionally create: `supabase/sql_src/functions/pseo/refresh_city_pseo_read_models.sql` only if a non-test caller requires compatibility
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] **Step 1: Rename the refresh function**

Define `public.refresh_pseo_read_models()` and preserve one transaction and one generated
`data_version`.

- [ ] **Step 2: Derive airport facts**

For every airport page, derive outbound distinct destinations/countries, inbound distinct
origins/countries, unioned operating-airline count, route durations, and minimum freshness from
`pseo_direct_routes`.

- [ ] **Step 3: Derive airport indexability**

Apply active/IATA/published/reviewed/route/access/source-rights/freshness gates and stable noindex
reasons. Parking and lounge absence must not block indexability.

- [ ] **Step 4: Synchronize the page registry**

Update matching airport and city `pseo_pages` with status, indexability, version, freshness, and
generation time.

- [ ] **Step 5: Resolve compatibility**

Search all callers. Remove the old function when no production caller exists; otherwise retain a
one-line PL/pgSQL/SQL wrapper that delegates directly to the shared refresh.

- [ ] **Step 6: Verify one coherent version**

Run both pSEO contracts and assert city page, airport page, route projection, and pSEO registry use
the same `data_version`.

### Task 7: Implement airport page and route-search RPCs

**Files:**

- Create: `supabase/sql_src/functions/pseo/rpc_get_airport_page.sql`
- Create: `supabase/sql_src/functions/pseo/rpc_search_airport_direct_routes.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] **Step 1: Implement `rpc_get_airport_page`**

Parse and resolve once, then compose normalized identity, reviewed metadata, cached facts, bounded
featured inbound/outbound routes, airline summaries, published guidance child rows, internal
links, and meta in `{ data, meta, error }`.

- [ ] **Step 2: Implement route-filter validation**

Validate direction, airline/country arrays, duration, seasonality, limit, and offset. Normalize IATA
and airline/country codes using existing helper conventions. Bound limit to 100.

- [ ] **Step 3: Implement the shared filtered relation**

Use one direction-normalized CTE over `pseo_direct_routes`, calculate results and facets from that
relation, apply deterministic ordering, and return canonical/indexability/version meta.

- [ ] **Step 4: Apply least privilege**

Revoke both functions from public/anon/authenticated and grant execute only to `service_role`.

- [ ] **Step 5: Register deterministic function order**

Place private helpers before public airport RPCs and the refresh before read RPC usage required by
tests.

- [ ] **Step 6: Run the airport contract**

Regenerate/reset and run `e2e_airport_pseo.sql`. Expected: all identity, content, route, filter,
facet, indexability, and privilege assertions pass.

### Task 8: Add deterministic development preview data and documentation

**Files:**

- Create: `supabase/seed/airport_pseo_fixture.sql`
- Modify: `supabase/config.toml` or the repository's existing seed include list
- Modify: `docs/features/pseo/README.md`

- [ ] **Step 1: Add one BKK airport page fixture**

Register a localized airport page and add minimal reviewed access, parking, lounge, notice, and FAQ
rows. Reuse existing normalized BKK and route fixtures. Mark all resulting pages noindex through
the development-source gate.

- [ ] **Step 2: Register seed order**

Load the airport fixture only after normalized route and city pSEO fixtures.

- [ ] **Step 3: Document contracts**

Document airport RPC examples, supported direction/filters, content ownership, canonical rules,
freshness/indexability, and explicit deferred scope.

- [ ] **Step 4: Inspect a real local payload**

Call both airport RPCs with BKK and confirm the envelope fields, counts, content ordering, facets,
noindex reason, and shared version match the seeded graph.

### Task 9: Full verification

**Files:**

- Regenerate: `supabase/migrations/*.sql`

- [ ] **Step 1: Rebuild from SQL source**

Run:

```bash
pnpm supabase:migrations:regenerate
pnpm supabase:reset
```

Expected: clean database rebuild from generated migrations and deterministic seeds.

- [ ] **Step 2: Run all relevant SQL contracts**

Run city pSEO, airport pSEO, city read-model, route discovery, database, RLS, privilege, public API,
and migration-source coverage checks exposed by repository scripts/snippets.

- [ ] **Step 3: Run code quality checks**

Run formatting/check scripts relevant to SQL and Edge code, plus:

```bash
git diff --check
```

Expected: all commands exit zero.

- [ ] **Step 4: Review final diff**

Confirm no generated migration was manually edited, no development fixture can become indexable,
no service-role secret is exposed, and no unrelated user change was modified.

- [ ] **Step 5: Report without committing**

Report `implemented: X; skipped: Y; add when: Z` with exact verification evidence. Do not commit,
push, or deploy unless the user separately authorizes it.
