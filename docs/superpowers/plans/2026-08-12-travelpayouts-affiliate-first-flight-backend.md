# Travelpayouts Affiliate-First Flight Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Realign Tripways flight backend and roadmap around short-lived Aviasales content observations and safe Travelpayouts affiliate handoff without treating Tripways as a schedule database.

**Architecture:** Keep OurAirports reference ingestion and existing route structures for local/provider-neutral discovery, but replace the price-range ingestion semantics with current cached-fare observations refreshed daily. Add provider-specific parsing only inside a Travelpayouts adapter, publish normalized observations atomically, omit expired observations at read time, and resolve affiliate redirects through server-owned allowlisted configuration.

**Tech Stack:** Supabase PostgreSQL, PL/pgSQL, Edge Functions on Deno/TypeScript, pg_cron, pg_net, Supabase Vault, Deno tests, SQL E2E snippets.

## Implementation outcome (2026-08-12)

The adapter, observation contract, atomic current-state publication, source rights, daily freshness
check/day-six refresh, pSEO payloads, allowlisted affiliate handoff, migrations, local reset and
focused E2E are implemented on `main`.

Two scope decisions supersede details in the original task list below:

- The physical `route_price_estimates` table and publish RPC names remain temporarily as compatibility
  names because active pSEO work already depends on them; their schema and public semantics are now
  observations and contain no price range.
- Affiliate handoff is a stateless RPC keyed by observation ID. Persistent handoff/click tables and a
  separate Edge redirect were intentionally not added: Tripways does not need a click-history database
  for this test phase, and analytics can be introduced behind the same boundary later.

Production secrets, remote cron activation and a real provider call remain deployment operations.

---

### Task 1: Realign roadmap and product contracts

**Files:**

- Modify: `docs/product/city-hub-provider-and-commercial-expansion-plan.md`
- Modify: `docs/product/p2-licensed-flight-data-prd.md`
- Modify: `docs/product/p3-commercial-mvp-prd.md`
- Modify: `docs/technical/p2-licensed-flight-data-technical-prd.md`
- Modify: `docs/technical/p3-commercial-mvp-technical-prd.md`
- Modify: `docs/technical/tripways-technical-roadmap.md`
- Modify: `docs/product/tripways-mvp-roadmap.md`
- Modify: `docs/features/pseo/README.md`
- Modify: `docs/features/route-discovery/README.md`

- [ ] Replace AirLabs-first phase assumptions with OurAirports reference data, Aviasales Data API content observations, and Travelpayouts affiliate handoff.
- [ ] State that indexed pages use cached Data API observations, while live-search pages require user initiation and `noindex`.
- [ ] Preserve future schedule enrichment as optional and explicitly remove AeroDataBox/AirLabs from current implementation scope.
- [ ] Run `rg -n -i "airlabs|aerodatabox" docs/product docs/technical docs/features` and verify remaining references are historical decisions or explicit exclusions only.
- [ ] Run `git diff --check -- docs`.

### Task 2: Define cached-fare observation contract with TDD

**Files:**

- Modify: `supabase/functions/v1/ingestion/price-estimates/tests/provider-contract.test.ts`
- Modify: `supabase/functions/v1/ingestion/price-estimates/provider-contract.ts`
- Create: `supabase/functions/v1/ingestion/price-estimates/providers/travelpayouts-provider.ts`
- Create: `supabase/functions/v1/ingestion/price-estimates/tests/travelpayouts-provider.test.ts`
- Create: `supabase/functions/v1/ingestion/price-estimates/fixtures/travelpayouts-sanitized-v1.json`

- [ ] Add failing tests for one observed amount, market, locale, dates, direct/transfer evidence, `found_at`, provider expiry, and a 24-hour maximum validity.
- [ ] Run the focused Deno tests and confirm failure because the observation schema and adapter do not exist.
- [ ] Replace `route-price-estimates.v1` range semantics with `flight-content-observations.v1`; preserve missing values as `null` and never synthesize ranges.
- [ ] Implement the Travelpayouts adapter against a sanitized synthetic fixture without storing raw responses.
- [ ] Run focused tests and confirm they pass.

### Task 3: Replace database price-range storage with current observations

**Files:**

- Modify: `supabase/functions/_shared/security/tests/provider_ready_schema_sql_contract.test.ts`
- Modify: `supabase/sql_src/schema/pseo/shared/route_price_estimates.sql`
- Modify: `supabase/sql_src/functions/ingestion/publish_price_estimate_batch.sql`
- Modify: `supabase/snippets/e2e_route_price_estimates.sql`
- Modify: `scripts/regenerate-supabase-migrations.sh`

- [ ] Add failing SQL contract tests requiring observed amount, market/locale, provider timestamps, departure/return dates, direct/transfer evidence, and no `price_min`/`price_max` range.
- [ ] Run the contract test and observe the intended failure.
- [ ] Rename the canonical source table to `flight_content_observations` and update generator ordering; keep public transport compatibility only where needed.
- [ ] Rewrite publication so the new batch atomically replaces previous observations for the same source/scope and deletes temporary provider records after success.
- [ ] Enforce `valid_until` as no later than provider expiry or 24 hours after observation.
- [ ] Update SQL E2E coverage for atomic replacement, missing price, expiry, and source rights.
- [ ] Run the focused contract and SQL checks.

### Task 4: Integrate daily Travelpayouts ingestion

**Files:**

- Modify: `supabase/functions/v1/ingestion/price-estimates/request.ts`
- Modify: `supabase/functions/v1/ingestion/price-estimates/service.ts`
- Modify: `supabase/functions/v1/ingestion/price-estimates/index.ts`
- Modify: `supabase/functions/v1/ingestion/price-estimates/tests/service.test.ts`
- Create: `supabase/sql_src/operations/configure_travelpayouts_content_cron.sql`
- Modify: `supabase/functions/_shared/security/tests/ingestion_sql_contract.test.ts`
- Modify: `scripts/regenerate-supabase-migrations.sh`
- Modify: `supabase/config.toml`

- [ ] Add failing service tests for adapter selection, bounded scope, daily idempotency, provider errors, and normalized publication input.
- [ ] Run focused tests and verify expected failures.
- [ ] Wire the provider through environment/Vault-backed credentials without accepting tokens in request bodies.
- [ ] Add a daily cron operation calling only the fixed ingestion function with the worker secret and deterministic UTC-date idempotency.
- [ ] Add contract tests ensuring secrets and provider payloads are absent from cron SQL and logs.
- [ ] Run focused Deno and SQL contract tests.

### Task 5: Update route and pSEO read models

**Files:**

- Modify: `supabase/sql_src/functions/pseo/shared/resolve_route_price_estimate.sql`
- Modify: `supabase/sql_src/functions/pseo/city/build_city_page_payload.sql`
- Modify: `supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql`
- Modify: `supabase/functions/_shared/security/tests/canonical_pseo_sql_contract.test.ts`
- Modify: `supabase/snippets/e2e_provider_ready_pages.sql`

- [ ] Add failing tests that require `observed` fare semantics, provenance/freshness, and omission after expiry.
- [ ] Verify tests fail against the existing range-based payload.
- [ ] Update SQL readers and page payloads to expose one recently observed amount with disclaimer, not a live offer or invented range.
- [ ] Ensure provider failure/expiry removes only the commercial module and does not deindex pages that satisfy non-commercial content gates.
- [ ] Run focused contract and E2E tests.

### Task 6: Add safe affiliate configuration and handoff boundary

**Files:**

- Create: `supabase/sql_src/schema/affiliate/affiliate_partners.sql`
- Create: `supabase/sql_src/schema/affiliate/affiliate_targets.sql`
- Create: `supabase/sql_src/schema/affiliate/affiliate_handoffs.sql`
- Create: `supabase/sql_src/schema/analytics/affiliate_click_events.sql`
- Create: `supabase/sql_src/functions/affiliate/create_affiliate_handoff.sql`
- Create: `supabase/functions/v1/affiliate/handoff/handler.ts`
- Create: `supabase/functions/v1/affiliate/handoff/index.ts`
- Create: `supabase/functions/v1/affiliate/handoff/tests/handler.test.ts`
- Modify: `scripts/regenerate-supabase-migrations.sh`
- Modify: `supabase/config.toml`

- [ ] Add failing tests for inactive partners, host/path allowlists, bounded non-personal SubIDs, expiry, tampering, and browser-supplied URL rejection.
- [ ] Run tests and observe expected failures.
- [ ] Implement private/admin configuration, short-lived opaque handoff records, minimal click events, and a thin Edge transport.
- [ ] Keep affiliate credentials and full targets server-side; return only a controlled redirect response.
- [ ] Run focused tests and security contract checks.

### Task 7: Regenerate migrations and verify the complete backend

**Files:**

- Regenerate: `supabase/migrations/*.sql`
- Modify as required: relevant SQL snippets and documentation indexes

- [ ] Run formatting on touched TypeScript, SQL, and Markdown files.
- [ ] Run all Deno tests and checks.
- [ ] Run `bash scripts/regenerate-supabase-migrations.sh` and confirm deterministic output.
- [ ] Reset local Supabase from generated migrations and seed.
- [ ] Run database, RLS, privilege, ingestion, pSEO, route-discovery, and affiliate E2E checks.
- [ ] Run `git diff --check` and inspect `git status --short` to confirm unrelated user changes were preserved.
- [ ] Do not configure remote secrets, remote cron, production publication, or indexability without separate approval.
