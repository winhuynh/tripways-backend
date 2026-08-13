# On-demand Travelpayouts Route Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace global Travelpayouts fare preloading with an origin-scoped cache-aside backend that fills only after a real browser request, while leaving frontend implementation as a documented handoff.

**Architecture:** Supabase Postgres owns canonical cache identity, leases, cooldown, origin-isolated publication, and read DTOs. A thin Edge Function checks cache, acquires one refresh lease, calls the provider on a miss, publishes a bounded normalized scope, and returns a stable envelope; page rendering never calls Travelpayouts synchronously.

**Tech Stack:** PostgreSQL 15, Supabase migrations/RLS/RPC, Supabase Edge Functions, Deno TypeScript, Travelpayouts Aviasales Data API v3, pg_cron, SQL rollback E2E tests.

---

## File map

**Create**

- `supabase/sql_src/schema/ingestion/flight_route_cache_states.sql`: internal cache key, lease, cooldown, demand, and result metadata.
- `supabase/sql_src/functions/ingestion/rpc_get_flight_route_cache.sql`: bounded public-safe cache read.
- `supabase/sql_src/functions/ingestion/rpc_claim_flight_route_cache_refresh.sql`: atomic fresh/cooldown/lease decision.
- `supabase/sql_src/functions/ingestion/publish_flight_route_cache_scope.sql`: origin-scoped atomic observation replacement and state finalization.
- `supabase/sql_src/functions/ingestion/rpc_publish_flight_route_cache_scope.sql`: service-role invoker wrapper.
- `supabase/sql_src/functions/ingestion/rpc_fail_flight_route_cache_refresh.sql`: bounded failure/cooldown finalization.
- `supabase/functions/v1/flight/route-cache/request.ts`: strict public request parser.
- `supabase/functions/v1/flight/route-cache/service.ts`: cache-aside orchestration.
- `supabase/functions/v1/flight/route-cache/handler.ts`: method, bot, rate-limit, and envelope boundary.
- `supabase/functions/v1/flight/route-cache/index.ts`: environment wiring and provider adapter.
- `supabase/functions/v1/flight/route-cache/tests/*.test.ts`: request, service, handler, and security behavior.
- `supabase/snippets/e2e_on_demand_flight_route_cache.sql`: cache lifecycle, isolation, cooldown, and privilege verification.
- `docs/superpowers/plans/2026-08-13-on-demand-route-cache-frontend-handoff.md`: frontend-only implementation plan.

**Modify**

- `supabase/sql_src/schema/flight_routing/flight_route_prices.sql`: add canonical cache scope fields/indexes needed for isolated replacement.
- `supabase/functions/v1/ingestion/price-estimates/providers/travelpayouts-provider.ts`: accept one request scope, explicit page, and result bound.
- `supabase/functions/v1/ingestion/price-estimates/provider-contract.ts`: include stable cache scope in normalized observation identity.
- `supabase/sql_src/functions/ingestion/publish_price_estimate_batch.sql`: retire provider-wide deletion after compatibility callers are removed.
- `supabase/sql_src/operations/configure_ingestion_crons.sql`: remove global Travelpayouts ingestion and refresh only demanded day-six scopes.
- `scripts/regenerate-supabase-migrations.sh`: include every new source exactly once.
- `supabase/config.toml`, `package.json`, `.env.example`: register/check the new Edge boundary and bounded configuration.
- `supabase/functions/_shared/security/tests/ingestion_sql_contract.test.ts`: schema, RLS, grants, cron, and isolation contracts.
- `supabase/functions/_shared/security/tests/provider_ready_schema_sql_contract.test.ts`: public DTO and no-provider-wide-delete contracts.
- `scripts/check-staging-readiness.sh`: required secrets/config and route-cache checks.
- `docs/technical/tripways-technical-roadmap.md`: replace preload/whole-batch statements with demand-driven cache-aside state.
- `docs/technical/first-cloud-staging-runbook.md`: replace manual global price ingestion with on-demand smoke steps.

## Task 1: Lock the cache contract with failing tests

- [ ] Add SQL contract assertions that `admin.flight_route_cache_states` exists, has RLS, grants only `service_role`, and contains `cache_key`, `origin_iata`, optional `destination_iata`, `market_code`, `currency_code`, `locale`, status, lease, cooldown, demand, and count fields.
- [ ] Assert price publication contains no unscoped `DELETE FROM public.flight_route_prices WHERE source_id = ...` and requires origin/market/currency/locale scope.
- [ ] Add Deno request tests with these accepted inputs:

```ts
assertEquals(
  parseRouteCacheRequest({
    origin: "bkk",
    destination: "lon",
    currency: "usd",
    market: "us",
    locale: "en-GB",
  }),
  {
    origin: "BKK",
    destination: "LON",
    currency: "USD",
    market: "us",
    locale: "en-GB",
  },
);
```

- [ ] Assert unknown fields, same endpoints, malformed codes, unsupported locale, and unbounded input return `ERR_INVALID_REQUEST`.
- [ ] Run:

```bash
deno test --config supabase/functions/deno.json --allow-read \
  supabase/functions/_shared/security/tests/ingestion_sql_contract.test.ts \
  supabase/functions/v1/flight/route-cache/tests
```

Expected: FAIL because the cache-state source and route-cache module do not exist.

## Task 2: Add the internal refresh-state schema

- [ ] Create `admin.flight_route_cache_states` with one unique canonical key and constraints equivalent to:

```sql
status IN ('idle', 'refreshing', 'fresh', 'empty', 'failed')
origin_iata ~ '^[A-Z]{3}$'
destination_iata IS NULL OR destination_iata ~ '^[A-Z]{3}$'
currency_code ~ '^[A-Z]{3}$'
market_code ~ '^[a-z]{2}$'
locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'
observation_count >= 0
```

- [ ] Add indexes for due demanded scopes and expired leases. Enable RLS, revoke `public/anon/authenticated`, and grant CRUD only to `service_role`.
- [ ] Add the schema source to `20260714080350_ingestion_schema.sql` generation.
- [ ] Run the focused SQL contract and observe PASS for the schema assertions.

## Task 3: Implement cache read, claim, and failure RPCs

- [ ] Write rollback SQL tests first for:
  - fresh cache returns `available` without a claim;
  - missing cache returns a claim token;
  - active lease returns `loading` without another claim;
  - empty cooldown returns `unavailable`;
  - expired lease can be reclaimed;
  - no response includes an internal UUID.
- [ ] Implement `rpc_get_flight_route_cache(JSONB)` as `SECURITY INVOKER`, service-role-only, with an explicit DTO allowlist.
- [ ] Implement `rpc_claim_flight_route_cache_refresh(JSONB)` using `INSERT ... ON CONFLICT`, row locking, and a generated opaque lease token. Update `last_requested_at` on every valid real-user request.
- [ ] Implement `rpc_fail_flight_route_cache_refresh(TEXT, TEXT)` so only the matching active lease can set `failed`, stable failure code, and bounded exponential `next_refresh_at`.
- [ ] Run the rollback test and privilege query; expect all assertions to pass and `anon/authenticated` execute privileges to be false.

## Task 4: Make provider loading bounded and paginated

- [ ] Replace the multi-origin adapter option with:

```ts
type TravelpayoutsLoadScope = {
  origin: string;
  destination: string | null;
  currencyCode: string;
  marketCode: string;
  locale: string;
  maxRecords: number;
};
```

- [ ] Write failing tests proving:
  - `page=1` is sent;
  - a full page advances to `page=2`;
  - a short page stops pagination;
  - the adapter never returns more than `maxRecords`;
  - destination is sent only for a route-page scope;
  - HTTP 429 produces `ERR_PROVIDER_RATE_LIMITED`;
  - timeout/5xx remains a stable provider failure.
- [ ] Implement pages with `limit = min(1000, remaining)`, `unique=true`, `sorting=route`, and an `AbortSignal.timeout` supplied by the caller.
- [ ] Include origin, destination, departure time, airline, market, currency, and locale in the normalized `sourceId` so pagination cannot collide.
- [ ] Run provider and contract tests; expect PASS.

## Task 5: Publish one cache scope without deleting other origins

- [ ] Add failing SQL E2E setup with existing SGN and BKK observations. Publish BKK and assert SGN remains unchanged.
- [ ] Extend `flight_route_prices` with constrained market/currency/locale scope indexes if existing columns are insufficient for deterministic replacement.
- [ ] Implement `admin.publish_flight_route_cache_scope(...)` to:
  1. validate the matching lease and source rights;
  2. validate at most the configured result bound;
  3. stage/resolve all rows before deletion;
  4. reject a non-empty provider batch when zero rows resolve;
  5. delete only matching provider + origin + optional destination + market + currency + locale rows;
  6. insert normalized rows;
  7. mark state `fresh` or `empty` with TTL/cooldown;
  8. publish read models only after a complete non-empty replacement.
- [ ] Add a service-role-only public invoker wrapper. Remove the on-demand path from the legacy provider-wide publisher; retain base ingestion untouched.
- [ ] Run `e2e_on_demand_flight_route_cache.sql`; expect origin isolation, empty cooldown, and atomic failure assertions to pass.

## Task 6: Add the cache-aside Edge Function

- [ ] Write service tests using dependency spies:

```ts
assertEquals(await executeRouteCache(input, depsWithFreshHit), freshEnvelope);
assertEquals(providerCalls, 0);
assertEquals(await executeRouteCache(input, depsWithClaim), filledEnvelope);
assertEquals(providerCalls, 1);
```

- [ ] Cover cache hit, miss fill, concurrent lease, empty, 429, timeout, failed publication, and preserved stale-cache fallback.
- [ ] Implement service flow: `get → claim → provider.load → publish`, calling failure finalization on bounded provider errors.
- [ ] Implement handler rules:
  - only `POST`;
  - parse bounded JSON;
  - hash IP and cache identity for rate limiting;
  - reject obvious crawler user agents from provider refresh while still returning cached data;
  - emit shared envelope and stable errors;
  - never log token, raw payload, full IP, affiliate path, or internal IDs.
- [ ] Wire server-only `TRAVELPAYOUTS_TOKEN`, maximum results, timeout, Supabase service key, and rate-limit consumer in `index.ts`.
- [ ] Register `flight-route-cache` in `supabase/config.toml` and `pnpm edge:check`.
- [ ] Run all route-cache Deno tests and `pnpm verify`; expect PASS.

## Task 7: Replace global cron with demand-only day-six refresh

- [ ] Add a failing SQL contract proving cron no longer calls the old global price-ingestion body and selects only cache states where:

```sql
status = 'fresh'
AND last_requested_at > now() - interval '30 days'
AND refreshed_at <= now() - interval '6 days'
AND next_refresh_at <= now()
```

- [ ] Keep the daily OurAirports job unchanged.
- [ ] Change the Travelpayouts cron to invoke a bounded internal refresh operation for due demanded scopes only; cap scopes per cron execution so daily provider budget cannot be exceeded.
- [ ] Remove `TRAVELPAYOUTS_ORIGINS` from `.env.example`. Add bounded settings for result count, timeout, recent-demand window, and daily scope budget.
- [ ] Update staging readiness checks and cron E2E assertions; expect PASS.

## Task 8: Update page state, roadmap, runbook, and frontend handoff

- [ ] Add an explicit price state to City and Route page DTOs: `available`, `loading`, or `unavailable`. Missing cache must not be an RPC error and must not invent an amount of zero.
- [ ] Write the frontend handoff plan with exact future files/components, SSR cache-hit behavior, skeleton, client fetch cancellation, empty/error CTA, disclosures, accessibility, analytics, and tests. State clearly that no frontend code exists in this cycle.
- [ ] Update the roadmap provider boundary to say:
  - no global preload;
  - cache-aside after browser skeleton render;
  - origin-scoped persistence;
  - day-six refresh only for recently demanded scopes;
  - crawler misses do not call Travelpayouts.
- [ ] Update the staging runbook with one cache-miss smoke, one cache-hit smoke, and origin-isolation verification.
- [ ] Run `rg` to ensure old whole-batch/preload and `TRAVELPAYOUTS_ORIGINS` guidance is absent from current technical docs.

## Task 9: Regenerate and verify from a clean local database

- [ ] Run `bash scripts/regenerate-supabase-migrations.sh`; expect every SQL source exactly once.
- [ ] Run `supabase db reset --local --yes`; expect all migrations and seeds to apply from an empty database.
- [ ] Run:

```bash
pnpm verify
deno test --config supabase/functions/deno.json --allow-read supabase/functions
for file in supabase/snippets/*.sql; do
  psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
    -v ON_ERROR_STOP=1 -f "$file"
done
git diff --check
```

- [ ] Query PostgreSQL to verify RLS on the cache state and price tables, zero public `SECURITY DEFINER` functions, no anon execution on cache RPCs, and no provider-wide deletion behavior.
- [ ] Report `implemented`, `skipped`, and `add when`. Do not commit, push, deploy, or mutate remote Supabase without separate user authorization.
