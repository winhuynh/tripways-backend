# Provider-Ready Page Data Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the local TripWays backend prove provider-neutral ingestion, zero-to-three-stop discovery, price estimates, and complete Homepage/City/Airport/Route page data contracts with deterministic fixtures.

**Architecture:** Provider adapters normalize external payloads into private raw batches. PostgreSQL validates rights, publishes canonical data atomically, rebuilds bounded route and pSEO read models, and owns indexability. Edge Functions remain stable thin transports, so switching providers changes only adapter registration, configuration, credentials, and operations.

**Tech Stack:** PostgreSQL 17, Supabase SQL/RPC/RLS, Deno TypeScript Edge Functions, Node/pnpm verification scripts.

---

### Task 1: Extend source rights and canonical ingestion contracts

**Files:**

- Modify: `supabase/sql_src/schema/flight_routing/data_sources.sql`
- Modify: `supabase/sql_src/schema/ingestion/raw_base_data_records.sql`
- Modify: `supabase/functions/v1/ingestion/base-data/provider-contract.ts`
- Modify: `supabase/functions/v1/ingestion/base-data/service.ts`
- Modify: `supabase/sql_src/functions/ingestion/publish_base_data_batch.sql`
- Test: `supabase/functions/v1/ingestion/base-data/tests/provider-contract.test.ts`
- Test: `supabase/functions/_shared/security/tests/ingestion_sql_contract.test.ts`
- Test: `supabase/snippets/e2e_base_data_ingestion.sql`

- [ ] Add failing contract tests for extended source rights and new canonical record types.
- [ ] Verify the focused tests fail for missing fields and unsupported record types.
- [ ] Add storage, retention, display, cache, attribution, and rights-validity columns with constraints.
- [ ] Extend raw record types and provider-neutral TypeScript DTOs for aliases, metro areas, terminals, airlines, routes, services, prices, and structured content.
- [ ] Extend publication validation without exposing raw provider payloads.
- [ ] Run focused Deno and SQL contract tests.

### Task 2: Add place discovery, terminals, and structured content schemas

**Files:**

- Create: `supabase/sql_src/schema/flight_routing/metro_areas.sql`
- Create: `supabase/sql_src/schema/flight_routing/metro_area_airports.sql`
- Create: `supabase/sql_src/schema/flight_routing/place_aliases.sql`
- Create: `supabase/sql_src/schema/flight_routing/nearby_airports.sql`
- Create: `supabase/sql_src/schema/flight_routing/airport_terminals.sql`
- Create: `supabase/sql_src/schema/flight_routing/airport_terminal_airlines.sql`
- Create: `supabase/sql_src/schema/pseo/city_facts.sql`
- Create: `supabase/sql_src/schema/pseo/airport_facilities.sql`
- Create: `supabase/sql_src/schema/pseo/airport_facts.sql`
- Test: `supabase/snippets/test_provider_ready_schema.sql`

- [ ] Write failing schema/constraint/RLS tests for every new table.
- [ ] Verify missing relations cause the intended failure.
- [ ] Add one focused source SQL file per table with explicit indexes, constraints, RLS, and service-role-only grants.
- [ ] Add citation, locale, verification, validity, status, source, and data-version fields to structured facts.
- [ ] Run the focused schema test.

### Task 3: Generalize route options to zero through three stops

**Files:**

- Modify: `supabase/sql_src/schema/route_discovery/route_options.sql`
- Modify: `supabase/sql_src/functions/route_discovery/refresh_route_options.sql`
- Modify: `supabase/sql_src/functions/route_discovery/rpc_search_routes.sql`
- Modify: `supabase/functions/v1/route-discovery/query/request.ts`
- Modify: `supabase/functions/v1/route-discovery/query/response.ts`
- Test: `supabase/snippets/e2e_route_discovery.sql`
- Test: `supabase/functions/v1/route-discovery/query/tests/request.test.ts`
- Test: `supabase/functions/v1/route-discovery/query/tests/response.test.ts`

- [ ] Add failing direct, one-, two-, and three-stop compatibility tests plus cycle, duration, and layover rejection cases.
- [ ] Verify two/three-stop expectations fail against the current model.
- [ ] Generalize ordered arrays and cardinality constraints while preserving direct/one-stop compatibility.
- [ ] Implement bounded recursive expansion with maximum three stops, no repeated airports, validity/day compatibility, layover bounds, duration cap, confidence threshold, deterministic pruning, and stable ranking.
- [ ] Extend request validation and facets to `max_stops <= 3`.
- [ ] Run route SQL and Edge tests.

### Task 4: Add provider-ready route price estimates

**Files:**

- Create: `supabase/sql_src/schema/pseo/route_price_estimates.sql`
- Create: `supabase/sql_src/functions/pseo/resolve_route_price_estimate.sql`
- Create: `supabase/sql_src/functions/ingestion/publish_price_estimate_batch.sql`
- Create: `supabase/functions/v1/ingestion/price-estimates/provider-contract.ts`
- Create: `supabase/functions/v1/ingestion/price-estimates/service.ts`
- Create: `supabase/functions/v1/ingestion/price-estimates/handler.ts`
- Create: `supabase/functions/v1/ingestion/price-estimates/index.ts`
- Test: `supabase/functions/v1/ingestion/price-estimates/tests/provider-contract.test.ts`
- Test: `supabase/snippets/e2e_route_price_estimates.sql`

- [ ] Write failing rights, bound, currency, expiry, freshness, and null-state tests.
- [ ] Add the estimate schema separately from live offers.
- [ ] Add provider-neutral adapter DTOs and a fixture adapter.
- [ ] Publish estimates only when source derived/display rights and freshness pass.
- [ ] Return stable missing/expired/unlicensed reasons rather than zero.
- [ ] Run focused SQL and Deno tests.

### Task 5: Add Homepage discovery read models and APIs

**Files:**

- Create: `supabase/sql_src/functions/pseo/rpc_search_places.sql`
- Create: `supabase/sql_src/functions/pseo/rpc_get_homepage_discovery.sql`
- Create: `supabase/functions/v1/homepage-page/query/request.ts`
- Create: `supabase/functions/v1/homepage-page/query/response.ts`
- Create: `supabase/functions/v1/homepage-page/query/handler.ts`
- Create: `supabase/functions/v1/homepage-page/query/index.ts`
- Test: `supabase/functions/v1/homepage-page/query/tests/request.test.ts`
- Test: `supabase/functions/v1/homepage-page/query/tests/response.test.ts`
- Test: `supabase/snippets/e2e_homepage_discovery.sql`

- [ ] Write failing tests for city, airport, metro, alias, nearby, featured-origin, route-map, multi-stop, duration, airline, connection, and price facets.
- [ ] Implement deterministic place ranking and version-consistent homepage payloads.
- [ ] Keep dated live search outside this API.
- [ ] Run focused RPC and Edge tests.

### Task 6: Extend City and Airport Hub contracts

**Files:**

- Modify: `supabase/sql_src/functions/pseo/rpc_get_city_page.sql`
- Modify: `supabase/sql_src/functions/pseo/rpc_search_city_direct_routes.sql`
- Modify: `supabase/sql_src/functions/pseo/rpc_get_airport_page.sql`
- Modify: `supabase/sql_src/functions/pseo/rpc_search_airport_direct_routes.sql`
- Modify: `supabase/functions/v1/city-page/query/response.ts`
- Create: `supabase/functions/v1/airport-page/query/response.ts`
- Test: `supabase/snippets/e2e_city_pseo.sql`
- Test: `supabase/snippets/e2e_airport_pseo.sql`

- [ ] Add failing tests for eligible price estimates, structured cited facts, terminals, facilities, nearby airports, and Route Page links.
- [ ] Extend City payload and price facets without converting missing price to zero.
- [ ] Extend Airport payload with terminals/facilities/facts and price facets.
- [ ] Preserve existing request contracts and direct-route behavior.
- [ ] Run City/Airport SQL and Edge tests.

### Task 7: Add complete Route Page pSEO domain and API

**Files:**

- Create: `supabase/sql_src/schema/pseo/route_pages.sql`
- Create: `supabase/sql_src/schema/pseo/route_page_faqs.sql`
- Create: `supabase/sql_src/schema/pseo/route_page_airport_comparisons.sql`
- Create: `supabase/sql_src/schema/pseo/route_page_travel_facts.sql`
- Create: `supabase/sql_src/schema/pseo/route_page_editorial_sections.sql`
- Create: `supabase/sql_src/functions/pseo/rpc_get_route_page.sql`
- Create: `supabase/sql_src/functions/pseo/rpc_search_route_options.sql`
- Create: `supabase/functions/v1/route-page/query/request.ts`
- Create: `supabase/functions/v1/route-page/query/response.ts`
- Create: `supabase/functions/v1/route-page/query/handler.ts`
- Create: `supabase/functions/v1/route-page/query/index.ts`
- Test: `supabase/functions/v1/route-page/query/tests/request.test.ts`
- Test: `supabase/functions/v1/route-page/query/tests/response.test.ts`
- Test: `supabase/snippets/e2e_route_page.sql`

- [ ] Add failing payload tests for direct/indirect 0–3 stops, hubs, schedules, price estimates, airports, map, facts, alternatives, FAQs, disclosure, canonical, freshness, and indexability.
- [ ] Add one focused source table per Route Page responsibility.
- [ ] Implement a version-consistent page-shell RPC and filter RPC.
- [ ] Explicitly return unknown for self-transfer, through baggage, fare rules, and live availability.
- [ ] Add the thin route-page Edge transport and tests.

### Task 8: Add sitemap/indexability and publication orchestration

**Files:**

- Modify: `supabase/sql_src/functions/pseo/refresh_pseo_read_models.sql`
- Create: `supabase/sql_src/functions/pseo/rpc_get_sitemap.sql`
- Create: `supabase/functions/v1/sitemap/query/handler.ts`
- Create: `supabase/functions/v1/sitemap/query/index.ts`
- Test: `supabase/snippets/e2e_pseo_indexability.sql`

- [ ] Write failing rights/freshness/confidence/editorial/canonical/fixture indexability tests.
- [ ] Rebuild Homepage, City, Airport, and Route read models in the same publication version.
- [ ] Add sitemap reads for published/indexable pages only.
- [ ] Verify fixture lineage is always excluded.

### Task 9: Add complete deterministic fixtures

**Files:**

- Modify: `supabase/seed/flight_routing_fixture.sql`
- Modify: `supabase/seed/city_pseo_fixture.sql`
- Modify: `supabase/seed/airport_pseo_fixture.sql`
- Create: `supabase/seed/provider_ready_page_fixture.sql`
- Modify: `supabase/seed/fixture.sql`

- [ ] Add multi-airport/metro/alias records.
- [ ] Add valid direct, one-, two-, and three-stop services and invalid-cycle/layover cases.
- [ ] Add valid, missing, expired, stale, and unlicensed price estimates.
- [ ] Add cited City/Airport facts, terminals, facilities, and complete Route Page content.
- [ ] Keep every fixture non-production and non-indexable.

### Task 10: Regenerate migrations and verify the foundation release

**Files:**

- Regenerate: `supabase/migrations/*.sql`
- Modify: `package.json` only if new focused verification commands are required.
- Modify: `docs/features/pseo/README.md`
- Modify: `docs/features/route-discovery/README.md`

- [ ] Run every new focused test and fix failures.
- [ ] Run `bash scripts/regenerate-supabase-migrations.sh` and verify deterministic output.
- [ ] Run a clean local Supabase reset and all SQL E2E snippets.
- [ ] Run Deno format, lint, typecheck, and tests.
- [ ] Run `pnpm verify`.
- [ ] Document the stable provider-switch procedure and explicit exclusions.
- [ ] Report `implemented`, `skipped`, and `add when` with exact verification evidence.
