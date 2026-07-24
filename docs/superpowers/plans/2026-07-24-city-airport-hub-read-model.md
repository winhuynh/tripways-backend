# City Airport Hub Read Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Return complete, derived, and editorially reviewed airport hub cards for city pSEO pages.

**Architecture:** Keep airport identity normalized, add airline business-model classification,
store locale-specific airport copy against the city page, derive reusable route statistics in a
private helper, and compose the public RPC from those sources. Regenerate the complete local
migration foundation from SQL source files.

**Tech Stack:** PostgreSQL 17, Supabase CLI, PL/pgSQL, deterministic SQL seeds, rollback-based SQL
contracts.

---

### Task 1: Define the failing contract

**Files:**

- Modify: `supabase/snippets/e2e_city_page_read_models.sql`

- [ ] Assert published BKK/DMK labels and descriptions.
- [ ] Assert exact route, airline, domestic, and international metrics from the seeded graph.
- [ ] Assert dominant airline business models and stable display order.
- [ ] Run the SQL contract and confirm it fails because the new response fields do not exist.

### Task 2: Add focused schema

**Files:**

- Modify: `supabase/sql_src/schema/flight_routing/airlines.sql`
- Create: `supabase/sql_src/schema/pseo/city_page_airport_content.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] Add constrained `airlines.business_model`.
- [ ] Add one content table with unique city-page/airport ownership, content validation, ordering,
      lifecycle validation, RLS, and service-role-only access.
- [ ] Add the table to the pSEO schema migration in dependency order.

### Task 3: Add reusable airport statistics

**Files:**

- Create: `supabase/sql_src/functions/pseo/get_city_airport_route_stats.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] Return one typed row per active city airport for a requested data version.
- [ ] Count distinct destinations and airlines.
- [ ] Derive domestic/international percentages from destination coverage.
- [ ] Derive the weighted dominant airline business model with deterministic tie-breaking.
- [ ] Place the private helper before public pSEO RPCs in generated migration order.

### Task 4: Compose the complete airport RPC

**Files:**

- Modify: `supabase/sql_src/functions/pseo/rpc_get_city_airports.sql`

- [ ] Join airport identity, primary-airport state, published page content, and helper statistics.
- [ ] Return the shared envelope with stable ordering and the resolved data version.
- [ ] Preserve missing-city and invalid-request errors.

### Task 5: Add deterministic Bangkok preview data

**Files:**

- Modify: `supabase/seed/flight_routing_fixture.sql`
- Modify: `supabase/seed/city_pseo_fixture.sql`

- [ ] Classify every seeded airline.
- [ ] Seed BKK and DMK hub labels, descriptions, and ordering after the Bangkok city page.
- [ ] Do not seed derived counts or percentages.

### Task 6: Regenerate and verify from zero

**Files:**

- Regenerate: `supabase/migrations/*.sql`

- [ ] Run `pnpm supabase:migrations:regenerate`.
- [ ] Run `pnpm supabase:reset`.
- [ ] Run both city pSEO SQL contracts and existing route-discovery contracts.
- [ ] Run formatting, edge checks, migration-source coverage, and `git diff --check`.
- [ ] Inspect the RPC payload and verify that its values match the rebuilt seeded graph.
