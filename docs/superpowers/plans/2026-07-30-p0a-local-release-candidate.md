# P0A Local Release Candidate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a deterministic local release candidate covering the P0A ingestion, publication, web-read, metadata, and reproducible-build requirements.

**Architecture:** Implement seven vertical slices across `tripways-backend` and `tripways-web`. PostgreSQL owns atomic publication and domain invariants, Edge Functions own privileged ingestion and public-read transport, and Next.js uses one server-only client boundary for city and airport pages.

**Tech Stack:** PostgreSQL/PL/pgSQL, Supabase CLI and Edge Functions, Deno/TypeScript, Next.js 16, React 19, Vitest, ESLint, Prettier.

---

### Task 1: Ingestion SQL contracts and storage

**Files:**

- Create: `supabase/functions/_shared/security/tests/ingestion_sql_contract.test.ts`
- Create: `supabase/sql_src/schema/ingestion/raw_import_batches.sql`
- Create: `supabase/sql_src/schema/ingestion/raw_base_data_records.sql`
- Create: `supabase/sql_src/schema/ingestion/ingestion_runs.sql`
- Create: `supabase/sql_src/schema/ingestion/ingestion_issues.sql`

- [ ] Write contract assertions requiring the four tables, source/checksum uniqueness, record
      validation states, atomic run mode, bounded issue fields, private/admin schema placement, and
      service-role-only privileges.
- [ ] Run
      `deno test --config supabase/functions/deno.json --allow-read supabase/functions/_shared/security/tests/ingestion_sql_contract.test.ts`
      and observe failure because the SQL source files do not exist.
- [ ] Add one focused table definition per source file. Use explicit constraints, indexes, grants,
      foreign keys to `admin.data_sources`, and no anon/authenticated grants.
- [ ] Re-run the contract test and require PASS.

### Task 2: Canonical provider parser and deterministic fixtures

**Files:**

- Create: `supabase/functions/v1/ingestion/base-data/provider-contract.ts`
- Create: `supabase/functions/v1/ingestion/base-data/providers/fixture-provider.ts`
- Create: `supabase/functions/v1/ingestion/base-data/providers/approved-api-provider.ts`
- Create: `supabase/functions/v1/ingestion/base-data/fixtures/base-data-v1.json`
- Create: `supabase/functions/v1/ingestion/base-data/fixtures/approved-api-sanitized-v1.json`
- Create: `supabase/functions/v1/ingestion/base-data/tests/provider-contract.test.ts`
- Create: `supabase/functions/v1/ingestion/base-data/tests/providers.test.ts`

- [ ] Write failing tests for version `base-data.v1`, valid country/city/airport parsing, duplicate
      source keys, missing required fields, invalid coordinate pairs, unresolved references, and
      preservation of unknown optional values as `null`.
- [ ] Run the two new Deno test files and observe missing-module failures.
- [ ] Implement explicit runtime parsers returning either a canonical batch or stable validation
      issues. Keep provider selection closed over `fixture` and `approved_api`; cap approved API records
      through server configuration and reject arbitrary URLs.
- [ ] Add deterministic fixtures containing the required valid and invalid scenarios and a sanitized
      bounded approved-API shape with no headers or secrets.
- [ ] Re-run the provider tests and require PASS without network access.

### Task 3: Atomic idempotent publication RPC

**Files:**

- Create: `supabase/sql_src/functions/ingestion/publish_base_data_batch.sql`
- Create: `supabase/tests/ingestion_base_data_e2e.sql`
- Modify: `supabase/sql_src/schema/flight_routing/cities.sql`
- Modify: `supabase/sql_src/schema/flight_routing/countries.sql`
- Modify: `supabase/sql_src/schema/flight_routing/airports.sql`

- [ ] Add rollback-based SQL tests proving a valid batch publishes country/city/airport records,
      invalid input leaves canonical counts unchanged, replay returns the existing run, unresolved
      references fail atomically, and optional unknowns stay `NULL`.
- [ ] Regenerate migrations, reset local Supabase, and run the SQL test to observe failure because
      the publication function is absent.
- [ ] Add only the provenance columns required for stable source record identity. Implement one
      privileged function with explicit `search_path`, stable error codes, source eligibility checks,
      validation before mutation, and one transaction-scoped publication flow.
- [ ] Regenerate migrations, reset local Supabase, and require all SQL scenarios to PASS.

### Task 4: Privileged ingestion Edge Function

**Files:**

- Create: `supabase/functions/v1/ingestion/base-data/request.ts`
- Create: `supabase/functions/v1/ingestion/base-data/service.ts`
- Create: `supabase/functions/v1/ingestion/base-data/handler.ts`
- Create: `supabase/functions/v1/ingestion/base-data/index.ts`
- Create: `supabase/functions/v1/ingestion/base-data/tests/request.test.ts`
- Create: `supabase/functions/v1/ingestion/base-data/tests/handler.test.ts`
- Create: `supabase/functions/v1/ingestion/base-data/tests/service.test.ts`
- Modify: `supabase/functions/deno.json`
- Modify: `.env.example`
- Modify: `package.json`

- [ ] Write failing tests for worker-secret auth, required `Idempotency-Key`, allowed source and
      provider modes, normalized hashed-IP rate limiting, duplicate mapping, validation mapping,
      publication failure mapping, bounded envelopes, and secret-free logs.
- [ ] Run the three new Deno test files and observe missing-module failures.
- [ ] Implement parse/validate/authorize/call-RPC/normalize/log/respond using existing shared Edge,
      Supabase, and rate-limit helpers. Add explicit environment validation and approved provider
      configuration placeholders.
- [ ] Add package scripts for ingestion tests and Edge checks; run them and require PASS.

### Task 5: Unified city and airport web transport

**Files:**

- Create: `tripways-web/src/lib/server/page-data-environment.ts`
- Create: `tripways-web/src/lib/server/page-data-transport.ts`
- Create: `tripways-web/src/lib/server/page-data-transport.test.ts`
- Modify: `tripways-web/src/features/city-page/infrastructure/city-page-environment.ts`
- Modify: `tripways-web/src/features/city-page/infrastructure/edge-city-page-repository.ts`
- Modify: `tripways-web/src/features/airport-page/infrastructure/airport-page-environment.ts`
- Modify: `tripways-web/src/features/airport-page/infrastructure/edge-airport-page-repository.ts`
- Modify: `tripways-web/src/features/city-page/domain/city-page-error.ts`
- Modify: `tripways-web/src/features/airport-page/domain/airport-page-error.ts`

- [ ] Write failing Vitest cases showing both repositories use the same server-only environment,
      timeout behavior, envelope parser hook, cache identity
      `{locale, entityIdentity, filters, dataVersion}`, 404 mapping, and page-specific dependency error.
- [ ] Run the focused transport and repository tests and observe expected failures from the missing
      shared module.
- [ ] Implement a small shared fetch transport with bounded timeout and stable non-sensitive errors;
      adapt both repositories without moving domain parsing into the transport.
- [ ] Re-run focused tests and require PASS.

### Task 6: Homepage inventory, bounded UI states, and indexing metadata

**Files:**

- Modify: `tripways-web/src/features/home-page/application/get-home-page-read-model.ts`
- Modify: `tripways-web/src/features/home-page/application/get-home-page-read-model.test.ts`
- Modify: `tripways-web/src/shared/ui/site-footer.tsx`
- Modify: `tripways-web/src/features/city-page/presentation/city-page.tsx`
- Modify: `tripways-web/src/features/airport-page/presentation/airport-page.tsx`
- Modify: `tripways-web/src/features/city-page/presentation/city-page-metadata.ts`
- Modify: `tripways-web/src/features/airport-page/presentation/airport-page-metadata.ts`
- Modify: `tripways-web/src/app/flights-from/[citySlug]/page.tsx`
- Modify: `tripways-web/src/app/airports/[airportSlug]/page.tsx`
- Create: `tripways-web/src/app/robots.ts`
- Create: `tripways-web/src/app/sitemap.ts`
- Create: `tripways-web/src/app/indexing-contract.test.ts`

- [ ] Write failing tests requiring inventory links to resolve to complete local content, placeholder
      actions to be absent or labelled preview, useful map fallback, finite loading/not-found/error
      outcomes, filter canonicalization, and `noindex` for every P0 page.
- [ ] Run focused Vitest tests and observe failures against current homepage and metadata behavior.
- [ ] Build the inventory from the supported local page identities, remove or disable speculative
      actions, normalize page errors, and implement metadata/robots/sitemap rules with safe title
      fallbacks.
- [ ] Re-run focused tests and require PASS.

### Task 7: Reproducible build, smoke tools, and acceptance evidence

**Files:**

- Modify: `tripways-web/src/app/layout.tsx`
- Modify: `tripways-web/.env.example`
- Modify: `tripways-backend/.env.example`
- Modify: `tripways-backend/package.json`
- Modify: `tripways-web/package.json`
- Create: `tripways-backend/scripts/smoke-approved-base-data-api.ts`
- Create: `tripways-backend/scripts/verify-p0a-local.sh`
- Create: `tripways-backend/docs/technical/p0a-local-release-candidate-acceptance.md`

- [ ] Add failing source-contract tests that reject network font imports, undocumented required
      environment variables, default-suite network calls, secrets in public variables, and missing P0A
      commands.
- [ ] Run the source-contract tests and observe the current reproducibility gaps.
- [ ] Use bundled/local font behavior, document placeholder environment values, add an explicit
      opt-in bounded approved-API smoke command, and compose the offline verification command without
      network access.
- [ ] Regenerate migrations and rebuild local Supabase from migration and seed.
- [ ] Run backend format check, Deno format/check/tests, SQL contract/E2E/security checks, web
      formatting check, lint, typecheck, Vitest, and production build.
- [ ] Run desktop/mobile browser smoke checks for homepage, city, airport, filters, and map fallback.
- [ ] Record command output and map evidence to all 12 capabilities. Mark capability 5 as the sole
      permitted exception only if approved provider credentials or owner approval are unavailable.
- [ ] Record the backend and web commit SHAs as the proposed immutable P0B source state without
      committing, pushing, deploying, or connecting an external service.
