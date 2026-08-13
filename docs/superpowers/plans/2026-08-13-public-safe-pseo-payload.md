# Public-safe pSEO Payload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove internal database identifiers from pSEO and affiliate public contracts.

**Architecture:** PostgreSQL builders create explicit public DTOs and persist lifecycle metadata in
versioned read models. Affiliate handoff resolves a dedicated opaque observation reference rather
than a database primary key.

**Tech Stack:** PostgreSQL, Supabase Edge Functions, Deno TypeScript

---

### Task 1: Define failing public-contract tests

**Files:**

- Modify: `supabase/functions/_shared/security/tests/provider_ready_schema_sql_contract.test.ts`
- Modify: `supabase/functions/_shared/security/tests/canonical_pseo_sql_contract.test.ts`
- Modify: `supabase/functions/v1/flight/affiliate-handoff/tests/request.test.ts`
- Create: `supabase/snippets/e2e_public_pseo_payload.sql`

- [ ] Assert that page builders use explicit route DTOs and contain no `to_jsonb(option)`.
- [ ] Assert that route observations expose `observation_ref`, not `observation_id`.
- [ ] Assert that affiliate request input is `observationRef`.
- [ ] Recursively reject public payload keys named `id` or ending in `_id`.
- [ ] Run the focused tests and observe failures caused by the old contract.

### Task 2: Add opaque observation reference

**Files:**

- Modify: `supabase/sql_src/schema/flight_routing/flight_route_prices.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/rpc_get_flight_affiliate_handoff.sql`
- Modify: `supabase/functions/v1/flight/affiliate-handoff/request.ts`
- Modify: `supabase/functions/v1/flight/affiliate-handoff/index.ts`

- [ ] Add a unique `public_reference` generated independently from the row primary key.
- [ ] Resolve affiliate handoffs by validated reference text.
- [ ] Update the Edge request and RPC argument to `observationRef`.
- [ ] Run focused affiliate and SQL contract tests until green.

### Task 3: Materialize public-safe page payloads

**Files:**

- Modify: `supabase/sql_src/functions/pseo/city/build_city_page_payload.sql`
- Modify: `supabase/sql_src/functions/pseo/airport/build_airport_page_payload.sql`
- Modify: `supabase/sql_src/functions/pseo/route/build_route_page_payload.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/refresh_page_read_models.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/rpc_get_page.sql`

- [ ] Replace whole-row route serialization with explicit JSON field allowlists.
- [ ] Remove entity UUIDs and use `observation_ref` in route observations.
- [ ] Store public lifecycle metadata alongside materialized page data.
- [ ] Return an opaque publication token instead of the publication UUID.
- [ ] Run focused pSEO contract tests until green.

### Task 4: Rebuild and verify

**Files:**

- Regenerate: `supabase/migrations/*.sql`

- [ ] Regenerate deterministic migrations.
- [ ] Reset local Supabase from migrations and seed.
- [ ] Run the public-payload SQL E2E.
- [ ] Run formatting, Edge typechecking, all Deno tests, SQL E2E, and `git diff --check`.
- [ ] Leave changes uncommitted and undeployed according to repository workflow rules.
