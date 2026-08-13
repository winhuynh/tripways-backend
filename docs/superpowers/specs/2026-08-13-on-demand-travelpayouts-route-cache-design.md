# On-demand Travelpayouts Route Cache Design

**Date:** 2026-08-13  
**Status:** Proposed for implementation  
**Scope:** Tripways backend implementation, frontend handoff plan, and roadmap updates

## 1. Objective

Tripways must not preload or periodically refresh fare observations for origins that have no user
demand. A pSEO page renders its reference content immediately. Its flight-route section reads a
bounded Travelpayouts cache and renders a skeleton when the cache is missing. The browser then asks
a server-owned endpoint to fill that cache on demand.

The implementation must preserve these facts:

- OurAirports proves only that countries, cities, and airports exist.
- A city pair is a journey-search identity, not proof that a flight route exists.
- Only a provider response can create flight evidence, airline facts, transfer facts, or an
  estimated price.
- Cached prices are estimates and never live inventory.
- A cache miss must not make the base pSEO page fail.

## 2. Architecture

### 2.1 Initial page render

The page gateway continues to read materialized page data from Supabase. Flight data has three
explicit states:

- `available`: fresh cached observations are included.
- `loading`: no fresh cache exists and the frontend may request an on-demand refresh.
- `unavailable`: a recent empty result or provider failure is under cooldown.

A cache miss is a valid response, not an RPC error. No provider call occurs inside the SQL page
builder or publication transaction.

### 2.2 Browser refresh request

The future frontend calls a dedicated public Edge endpoint after rendering the skeleton. The
request contains a bounded canonical identity:

```json
{
  "origin": "BKK",
  "destination": "LON",
  "currency": "USD",
  "market": "us",
  "locale": "en-GB"
}
```

`destination` is optional for a City Page and required for a Route Page. The Edge Function parses,
rate-limits, and calls one database orchestration RPC. It never returns the Travelpayouts token,
raw payload, database identifiers, or provider errors.

### 2.3 Cache-aside orchestration

The database orchestration boundary performs this sequence:

1. Resolve the origin and optional destination against canonical active airports or city IATA
   identities.
2. Return fresh cached observations immediately when present.
3. Return a stable cooldown response after a recent empty result or failed refresh.
4. Acquire a per-cache-key advisory lock so concurrent misses do not create duplicate provider
   work.
5. Recheck the cache after acquiring the lock.
6. Allow the Edge Function to call Travelpayouts only when a refresh is still required.
7. Publish normalized observations for exactly one origin/cache scope.
8. Return the new bounded route DTO.

Because PostgreSQL cannot call Travelpayouts directly, the Edge Function owns the network call while
Postgres owns cache identity, leases, cooldown, publication, and isolation invariants.

## 3. Persistence model

### 3.1 Flight observations

`public.flight_route_prices` remains the normalized short-lived provider cache. It stores only
records actually returned and accepted from Travelpayouts. It does not store every possible city
pair or raw provider responses.

Publication changes from provider-wide replacement to origin-scoped replacement. Publishing BKK
must never delete SGN observations. A successful non-empty refresh replaces the matching provider,
market, currency, locale, and origin scope atomically.

### 3.2 Refresh state

Add one internal admin table that records bounded cache coordination metadata, not provider content:

- canonical cache key;
- origin and optional destination code;
- market, currency, and locale;
- status: `idle`, `refreshing`, `fresh`, `empty`, or `failed`;
- lease expiry;
- last attempted/succeeded timestamps;
- next allowed refresh timestamp;
- current observation count;
- stable failure code;
- created and updated timestamps.

The table is service-role only. No client receives its primary key or operational fields.

This state prevents duplicate calls, supports empty-result cooldown, and identifies only origins
that users have actually requested. It is not a queue of all possible routes.

## 4. Cache policy

- Freshness window: up to seven days and never beyond provider `expires_at`.
- Proactive refresh threshold: day six, only for cache keys that have been requested recently.
- Empty-result cooldown: 24 hours.
- Provider failure cooldown: exponential bounded backoff, beginning at 15 minutes.
- Refresh lease: short and recoverable after worker interruption.
- Result bound: store and return only the configured maximum useful routes per origin.
- Pagination: supported explicitly; stop on an empty/short page or the configured result bound.
- Rate limiting: per caller IP hash and per canonical cache key.
- Daily budget: fail closed with a stable unavailable response when exhausted.

The existing daily cron no longer scans a configured global origin list for prices. It selects only
previously requested cache keys that are on day six and still inside the recent-demand retention
window.

## 5. Public response

The on-demand endpoint returns the shared envelope:

```json
{
  "data": {
    "status": "available",
    "origin": "BKK",
    "destination": null,
    "routes": []
  },
  "meta": {
    "cache": "miss_filled",
    "observedAt": "2026-08-13T00:00:00Z",
    "validUntil": "2026-08-19T00:00:00Z"
  },
  "error": null
}
```

Public route items use an explicit allowlist: public airport codes, destination code, provider
airline IATA when present, transfer count, estimated amount/currency, observed/departure dates,
freshness, and opaque observation reference. Internal UUIDs and provider source IDs are excluded.

## 6. SEO and crawler behavior

- A cache-miss page renders reference content and a skeleton without failing.
- Pages without fresh flight evidence remain `noindex`.
- Client requests identified as obvious crawlers do not trigger Travelpayouts network calls.
- After a real-user cache fill, later SSR/publication reads can include the fresh route data.
- A page becomes indexable only through the existing publication quality gate.
- Absence from a Travelpayouts response is not presented as proof that no flight exists.

## 7. Failure handling

- Travelpayouts timeout, HTTP 429, 5xx, malformed payload, or empty data returns a stable bounded
  response; the base page remains usable.
- Existing unexpired observations remain visible if a refresh fails.
- A partial provider fetch cannot replace a previously complete scope.
- A failed origin refresh cannot delete or invalidate another origin.
- Logs contain request ID, cache key hash, action, status, duration, record count, and stable error
  code; they exclude token, raw payload, full IP, affiliate path, and database IDs.

## 8. Backend implementation scope

- Replace provider-wide price publication with origin-scoped atomic publication.
- Add refresh-state schema and least-privilege grants.
- Add cache lookup/lease/finalization RPCs with one function per SQL source file.
- Add a cache-aside Edge Function using the existing Travelpayouts adapter and shared contracts.
- Add Travelpayouts pagination and a configurable bounded result count.
- Change scheduled price refresh to operate only on recently demanded day-six cache keys.
- Preserve the existing provider-neutral adapter boundary.
- Update page/read-model payloads so missing price data is an explicit valid state.
- Regenerate clean migrations from `supabase/sql_src`.

## 9. Frontend handoff scope

No frontend implementation is included because the frontend has not been built. Add one detailed
plan document to the backend repository covering:

- SSR cache-hit rendering;
- cache-miss skeleton;
- client request lifecycle and cancellation;
- available, empty, cooldown, timeout, and error states;
- estimated-price disclosure and affiliate CTA;
- accessibility and reduced-motion behavior;
- analytics without triggering provider fetch from crawlers;
- frontend tests and acceptance criteria.

## 10. Tests and acceptance criteria

Implementation is complete only when tests prove:

- cache hit does not call Travelpayouts;
- cache miss calls it once and returns normalized routes;
- concurrent misses for one cache key do not publish twice;
- publishing one origin preserves all other origins;
- empty and failed calls respect cooldown;
- expired leases recover safely;
- pagination is bounded and deterministic;
- provider timeout/429/5xx does not fail the page contract;
- crawler requests cannot trigger provider network calls;
- token, raw payload, internal IDs, and raw provider errors never enter public output or logs;
- day-six cron selects only recently demanded cache keys;
- local migration reset, RLS, privilege checks, Deno tests, SQL E2E, formatting, and type checks pass.

## 11. Explicit exclusions

- No preload of 10,000 routes.
- No materialization of all possible city pairs.
- No live ticket inventory or schedule database.
- No synchronous provider call inside SSR, SQL page builders, or publication transactions.
- No frontend code in this implementation cycle.
- No cloud deployment, remote migration, commit, or push without separate authorization.
