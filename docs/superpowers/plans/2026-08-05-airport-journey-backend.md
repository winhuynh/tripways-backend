# Airport Journey Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy flight-first Airport Hub backend contract with a journey-led Airport Page payload and a verified direct-flight search in both airport directions.

**Architecture:** Keep the in-progress canonical `rpc_get_page` and `rpc_search_routes` refactor. PostgreSQL remains the source of truth for reviewed journey content, source provenance, publishability, and direct-route eligibility; the Airport Page payload contains editorial guidance while verified flights are queried separately through one bounded canonical route RPC.

**Tech Stack:** PostgreSQL 17, Supabase SQL source generation, Deno contract tests, rollback-based SQL verification.

---

### Task 1: Define the new contract in failing tests

**Files:**

- Modify: `supabase/functions/_shared/security/tests/canonical_pseo_sql_contract.test.ts`
- Modify: `supabase/snippets/e2e_provider_ready_pages.sql`

- [ ] Require airport journey schema, journey payload keys, removal of featured route payloads, and the new airport route-search scope.
- [ ] Require airport route search to be direct-only in both `from` and `to` directions with only counterpart search, route type, operating airline, and geography filters.
- [ ] Run the focused Deno contract and observe RED for the missing journey contract.

### Task 2: Replace legacy Airport Hub schema

**Files:**

- Modify: `supabase/sql_src/schema/pseo/airport/airport_pages.sql`
- Modify: `supabase/sql_src/schema/pseo/airport/airport_content_sections.sql`
- Create: `supabase/sql_src/schema/pseo/airport/airport_journey_steps.sql`
- Modify: `supabase/sql_src/schema/pseo/airport/airport_access_options.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] Remove route-led summaries, cached route counts, and duration fields from `airport_pages`.
- [ ] Add reviewed airport orientation, arrival/departure summaries, city-distance context, and separate editorial/route freshness metadata.
- [ ] Add ordered sourced journey steps for arrival/departure and domestic/international/all audiences.
- [ ] Extend transport options with journey direction, pickup summary, best-for label, and accessibility/luggage notes.
- [ ] Add the new table to deterministic migration ordering and run source-format checks.

### Task 3: Build the journey-led page payload

**Files:**

- Modify: `supabase/sql_src/functions/pseo/airport/build_airport_page_payload.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/refresh_page_read_models.sql`

- [ ] Replace featured outbound/inbound routes, airline summary, and price summary with `orientation`, `quick_answers`, `arrival`, `departure`, `transport`, curated airport modules, FAQs, and provenance.
- [ ] Keep verified flights out of the immutable editorial payload and expose route refresh identity in provenance.
- [ ] Update publishability gates to require reviewed arrival, departure, and transport utility rather than route-led copy.

### Task 4: Add verified two-direction airport flight search

**Files:**

- Modify: `supabase/sql_src/functions/route_discovery/rpc_search_routes.sql`
- Modify: `supabase/functions/_shared/contracts/route-filters.ts`
- Modify: `supabase/functions/v1/route-search/query/rpc-input.ts`
- Modify: related tests under `supabase/functions/_shared/contracts/tests` and `supabase/functions/v1/route-search/query/tests`

- [ ] Add canonical airport scope `{ type: "airport", key: "BKK", direction: "from" | "to" }`.
- [ ] Force `stop_count = 0` for airport scope and normalize counterpart identity for both directions.
- [ ] Support only counterpart query, domestic/international, operating airline, counterpart country/region, bounded page size, and cursor for Airport Page use.
- [ ] Return direction-aware facets from the same eligible filtered relation.

### Task 5: Seed, regenerate, and verify

**Files:**

- Modify: `supabase/seed/provider_ready_page_fixture.sql`
- Modify: `supabase/snippets/e2e_provider_ready_pages.sql`
- Regenerate: `supabase/migrations/*.sql`

- [ ] Seed reviewed BKK arrival/departure steps and transport comparison content.
- [ ] Regenerate migrations from `sql_src`, reset local Supabase, and run SQL journey and two-direction direct-flight assertions.
- [ ] Run Deno format/check/tests, security guards, migration checks, and `git diff --check`.
