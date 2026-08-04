# Shared Page Read Model and Clean Architecture Design

## Goal

Refactor the TripWays backend so Homepage, City Hub, Airport Hub, and Route Page load from one
version-consistent page read model per request, while all route-search behavior reuses one shared,
indexed search projection and one set of validation and serialization rules.

The refactor may introduce breaking local API changes. Correctness, clarity, reuse, and production
query performance take priority over preserving the current local contracts.

## Scope

Included:

- Review all current TypeScript helpers, Edge transports, PostgreSQL functions, schemas, indexes,
  read models, fixtures, and tests touched by page reads and route search.
- Consolidate genuinely shared validation, envelope, handler, route-filter, price-eligibility,
  serialization, and read-model behavior.
- Give each page a single page-shell RPC backed by one materialized page snapshot.
- Give all interactive route lists and maps one shared route-search RPC and projection.
- Replace deep offset pagination with a deterministic keyset cursor where result scale warrants it.
- Add query-plan and scale-oriented performance verification.
- Preserve RLS, least privilege, source rights, fixture noindex behavior, and stable public errors.

Excluded:

- UI implementation.
- Live dated availability, offers, booking, and affiliate redirects.
- Production provider credentials and scheduler deployment.
- A generic framework for unrelated future domains.

## Current Findings Driving the Refactor

The current foundation is functionally verified but contains architectural debt:

- City, Airport, Homepage, Route Page, and generic Route Discovery parse overlapping filters with
  different bounds and names.
- TypeScript repeats record, code, locale, numeric, list, pagination, and envelope validation.
- Several new SQL functions are dense and combine parsing, scoping, filtering, serialization,
  facets, and page composition in one file.
- Route filtering, route path construction, price eligibility, route serialization, and facets are
  repeated across page-specific RPCs.
- Some page-shell RPCs perform many correlated subqueries at request time rather than reading one
  precomposed snapshot.
- Pagination semantics are inconsistent and rely on offset in places that may scale deeply.
- `data_version` exists but is not expressed through one shared publication boundary for every page
  snapshot and search projection.

## Chosen Architecture

### 1. Shared TypeScript Boundary Primitives

Create focused helpers under `supabase/functions/_shared/contracts/`:

- `guards.ts`: `isRecord` and structural boundary guards.
- `primitives.ts`: bounded integer, non-negative number, slug, locale, IATA, airline code, currency,
  and unique code-list parsers.
- `route-filters.ts`: the single runtime parser and canonical TypeScript type for route filters.
- `rpc-envelope.ts`: the shared `data/meta/error` envelope validator.
- `query-handler.ts`: the thin POST query orchestration shared by page query endpoints.

Helpers remain small functions rather than class hierarchies or factories. Each extracted helper
must have at least two real consumers. Feature-specific identity and editorial validation stays
with its feature.

### 2. Canonical Route Search Projection

Replace page-specific route query duplication with one rebuildable relational projection containing
all fields needed for search and serialization:

- Origin and destination city and airport identities.
- Ordered leg, airline, and connection arrays.
- Stop count, schedule pattern, durations, and confidence.
- Stable rank keys and one publication `data_version`.
- Display-safe price-estimate state and searchable price fields when licensed and fresh.
- Precomputed route canonical path.

The projection remains relational. JSON is produced at the API/read-model boundary, not stored as
the only searchable truth.

One shared SQL search function owns:

- Scope: global, origin city, origin airport, or exact city pair.
- Stops, airline, connection airport, duration, layover, cabin, and price filters.
- Stable ranking and keyset pagination.
- Facets derived from the same filtered relation and data version.
- Shared route serialization and explicit unknown operational fields.

Homepage, City Hub, Airport Hub, Route Page, and generic Route Discovery become thin wrappers that
resolve page identity/scope and invoke this function. They do not duplicate filtering rules.

### 3. One Page-Specific Materialized Snapshot per Page Load

Use four physically separate read-model tables rather than one universal page table:

- `homepage_read_models`
- `city_page_read_models`
- `airport_page_read_models`
- `route_page_read_models`

Each table has one current row per page identity, locale, and publication version. Page-specific
tables keep refresh cadence, indexes, constraints, payload shape, and future evolution independent.
They avoid a universal nullable schema or one oversized JSON contract.

Each row stores bounded JSON modules for its complete page shell:

- Shared metadata: identity, SEO, canonical path, indexability, freshness, and data version.
- Homepage: featured origins, place-search bootstrap, initial route-map result, and filter metadata.
- City: city/country identity, airport summaries, quick facts, structured facts, featured direct
  routes, airlines, internal links, FAQs, and initial price state.
- Airport: identity, quick facts, terminals, facilities, access, parking, lounges, notices, nearby
  airports, routes, internal links, FAQs, and initial price state.
- Route: origin/destination identity, summary, initial options, price state, airport comparison,
  travel facts, editorial sections, FAQs, unknowns, and disclosure.

Each page-shell RPC performs only:

1. Validate and normalize page identity.
2. Resolve the current published snapshot row.
3. Return the stored payload and metadata.

The request path must not traverse the route graph or rebuild large aggregates. Interactive filters
use the shared search RPC after initial load. Initial route lists are bounded bootstrap results,
never the unbounded route corpus.

### 4. Atomic Refresh and Publication

The refresh flow builds in this order:

1. Canonical route options.
2. Shared route-search projection.
3. Page facts and page-specific relational modules.
4. Complete rows in each affected page-specific read-model table.
5. Indexability and sitemap state.

All outputs share one `data_version`. A new version becomes current only after every required stage
succeeds. Failed refreshes leave the previous current version readable. Development fixture lineage
always forces `is_indexable = false` and `noindex_reason = development_fixture`.

### 5. Performance Strategy

- Composite btree indexes begin with equality scope columns and end with range/rank columns.
- GIN indexes support airline and connection arrays only where measured query plans use them.
- Partial indexes cover published, current, display-eligible, and sitemap reads.
- Every foreign-key join used in refresh or page composition is audited for a supporting index.
- Keyset cursors contain all deterministic ordering columns and the UUID tie-breaker.
- Each page read model uses a direct unique lookup by its native identity, locale, and current
  publication marker.
- Payload modules are bounded during refresh; no page read model contains unbounded route lists.
- Refresh queries may be expensive but remain outside the public request path.

Performance verification uses `EXPLAIN (ANALYZE, BUFFERS)` for:

- One indexed lookup against the page-specific read-model table for each page type.
- Route search by origin city, origin airport, and exact city pair.
- Stops, airline, connection, duration, layover, and price filters.
- Keyset pagination after a deep logical position.
- Sitemap reads.

Tests assert query shape and index usage on a deterministic synthetic scale fixture. Timing is
reported as evidence but not encoded as a brittle machine-specific assertion. Public page-shell
RPCs are additionally checked to execute one page-specific read-model lookup and return one data
version.

## API Shape

All page-shell endpoints use one action and one response envelope:

```json
{
  "action": "get_page",
  "input": {
    "page_type": "city",
    "entity_key": "bangkok",
    "locale": "en-GB"
  }
}
```

The response is:

```json
{
  "data": {},
  "meta": {
    "page_type": "city",
    "canonical_path": "/flights-from/bangkok",
    "data_version": "uuid",
    "is_indexable": false,
    "noindex_reason": "development_fixture",
    "generated_at": "timestamp"
  },
  "error": null
}
```

All route interactions use one canonical filter contract:

```json
{
  "scope": {
    "type": "origin_city",
    "key": "bangkok"
  },
  "filters": {
    "max_stops": 3,
    "airlines": ["TG"],
    "connection_airports": ["SIN"],
    "max_duration_minutes": 1200,
    "max_layover_minutes": 300,
    "cabin": "economy",
    "price_max": 900,
    "currency": "USD"
  },
  "page_size": 20,
  "after": null
}
```

Missing price does not pass a numeric price filter. Missing display-safe price remains an explicit
state and never becomes zero.

## Error Handling and Security

- Shared boundary parsers reject unknown fields and unbounded values.
- PostgreSQL revalidates domain invariants and never trusts the Edge transport.
- Page and search RPCs are service-role-only; Edge functions are the public boundary.
- Raw provider payloads remain private.
- No `SECURITY DEFINER` function is placed in an exposed schema.
- Every exposed table has RLS and least-privilege grants.
- Errors remain stable `ERR_*` codes without provider or database details.

## Testing Strategy

1. Characterization tests record the required product behavior before refactoring.
2. Shared TypeScript helpers are tested once, followed by thin consumer contract tests.
3. Shared SQL search tests prove identical filter semantics across every scope.
4. Page-specific read-model tests prove one row, one version, bounded modules, and complete page
   content.
5. Refresh tests prove atomic version publication and rollback to the prior readable version on
   failure.
6. Security tests prove RLS, grants, fixture noindex behavior, and service-role-only RPC access.
7. Query-plan tests capture `EXPLAIN (ANALYZE, BUFFERS)` evidence and flag unexpected sequential
   scans on scale tables.
8. Clean database reset, all SQL snippets, Deno format/lint/typecheck/tests, Prettier, and diff checks
   remain mandatory.

## Migration and Compatibility

Because the backend is local, old request and response contracts may be removed after all consumers
and tests move to the canonical contracts. Generated migrations are rebuilt exclusively from
`supabase/sql_src`. No compatibility shims or deprecated duplicate RPCs remain after the refactor.

## Success Criteria

- One page-shell request performs one current lookup against its page-specific read-model table.
- All route search consumers share one canonical parser, projection, search function, serializer,
  facets implementation, and pagination model.
- No duplicated price eligibility, canonical route path, route-filter, or operational-unknown logic
  remains in page RPCs.
- SQL follows repository formatting and file responsibility rules.
- Shared abstractions have at least two real consumers.
- Clean reset exposes a complete 0–3-stop fixture snapshot.
- All functional, security, and performance verification passes with query-plan evidence.
