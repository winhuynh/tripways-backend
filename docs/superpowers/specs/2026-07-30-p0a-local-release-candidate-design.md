# P0A Local Release Candidate Design

**Status:** Approved direction, pending written-spec review  
**Date:** 2026-07-30  
**Repositories:** `tripways-backend`, `tripways-web`  
**Source requirements:** `docs/product/p0-staging-readiness-prd.md`,
`docs/technical/p0a-local-release-candidate-technical-prd.md`

## Objective

Produce a deterministic local release candidate that proves the P0 product journeys and the minimum
base-data ingestion path end to end. The release candidate must satisfy at least 11 of the 12 P0A
capabilities, keep all P0 provider data non-production and non-indexable, and leave an explicit source
state for P0B.

## Chosen Approach

Implement the release candidate as vertical slices rather than completing each repository or layer
in isolation. Each slice starts with a failing contract or behavior test, adds the minimum database
and transport behavior needed to pass, and finishes with an end-to-end verification point.

The slices are:

1. Ingestion storage and security boundary.
2. Canonical provider contract and deterministic offline fixtures.
3. Atomic, idempotent publication.
4. Privileged ingestion Edge Function.
5. Unified city and airport server-read transport.
6. Homepage inventory, metadata, error states, and cache identity.
7. Reproducible build and P0A acceptance evidence.

This order exposes contract mismatches early while keeping every intermediate state testable.

## Architecture

### Backend ingestion flow

`POST /functions/v1/ingestion/base-data` is a thin privileged transport. It authenticates the local
worker, validates the bounded request, normalizes and hashes the caller IP for rate limiting, selects
a server-configured provider adapter, and invokes private database RPCs. It never accepts a provider
URL from the caller and never logs secrets, full IP addresses, or raw provider payloads.

The selected adapter produces one neutral canonical envelope containing versioned country, city, and
airport records. The fixture adapter is completely offline. The optional approved-API adapter uses a
server allowlist, a bounded record count, and environment-only credentials. Both adapters pass
through the same parser and validation rules.

Raw receipt data is stored only in `private.raw_import_batches` and
`private.raw_base_data_records`. Operational results are stored in `admin.ingestion_runs` and
`admin.ingestion_issues`. Neither schema is exposed through the Data API.

### Publication transaction

A private, privileged PostgreSQL function owns validation and publication. P0A uses atomic-batch
semantics:

- Any invalid, duplicate-conflicting, or unresolved required record fails the run.
- A failed run records bounded operational evidence but does not modify canonical country, city, or
  airport data.
- A successful run upserts the complete valid batch in one transaction.
- Reusing the same source and checksum or idempotency identity returns the existing result without
  creating canonical duplicates.
- Unknown optional values remain `NULL`; the publisher does not infer timezone, coordinates,
  airport-city relationships, or production eligibility.

Canonical records preserve source provenance and remain development-only. Publication never enables
`production_allowed`, `seo_allowed`, or page indexability.

### Public read boundary

City and airport pages use one server-only transport module and one environment contract. The module
calls the approved public-read Edge Function boundary and provides:

- bounded timeout behavior;
- runtime parsing of the shared data/meta/error envelope;
- stable mapping of missing identity to not-found;
- stable mapping of timeout, malformed envelope, and dependency failure to the page-specific error
  code;
- cache identity containing locale, entity identity, normalized filters, and `data_version`.

The web application never calls public RPCs with the service-role key from feature-specific code.
Service-role access remains inside Edge Functions.

### Web inventory and rendering

The homepage read model lists only local city and airport pages backed by complete published data.
Placeholder routes, inactive newsletter actions, and fake legal links are removed, disabled, or
explicitly labelled preview. Route-map dependency failure renders a useful fallback.

City and airport pages terminate in one of three bounded outcomes: content, not found, or dependency
error. Optional sections may fail independently only when the identity and primary page model remain
valid. Filters preserve a canonical URL to the base page and produce either a result set or an
intentional empty state.

### Metadata and indexing

All local, fixture-derived, sanitized-API, and staging P0 pages emit `noindex`. Filtered URLs
canonicalize to their unfiltered base page. Metadata generation uses bounded fallbacks so a failed
dependency cannot hang rendering or duplicate titles. Robots and sitemap behavior exclude P0
provider pages from production indexing.

### Environment and build

Both repositories document every required variable in `.env.example` using non-secret placeholders.
Environment parsing fails fast with stable setup errors and never echoes secret values. Production
builds use local or bundled fonts so they do not depend on an external font download.

## Data Model

### `private.raw_import_batches`

Stores the source, provider version, checksum, idempotency identity, receipt timestamp, optional
source timestamp, and batch status. A source/checksum uniqueness constraint enforces replay safety.

### `private.raw_base_data_records`

Stores batch membership, record type, bounded source key, JSONB payload, and validation state. The
table is private, has no public grants, and retains unknown fields only inside the raw boundary.

### `admin.ingestion_runs`

Stores the batch, action, atomic mode, accepted/rejected counts, status, stable error code, and
timestamps. It is operational evidence, not a public application model.

### `admin.ingestion_issues`

Stores the run, hashed or bounded source identity, issue code, and severity. It does not store full
raw payloads or credentials.

Existing canonical `public.countries`, `public.cities`, and `public.airports` remain the authoritative
read-side entities. Their current source and eligibility columns will be reused where adequate;
schema additions will be limited to fields required to preserve provenance, null-safe mapping, and
development-only publication.

## Provider Contract

The versioned canonical input supports:

- Country: ISO code and name.
- City: source ID, name, country ISO, and optional coordinates.
- Airport: source ID, name, optional IATA/ICAO, city reference, country ISO, optional coordinates,
  and type.

The deterministic fixture set contains:

- one valid country, city, and airport path;
- a duplicate identity;
- a missing required value;
- an invalid coordinate;
- an unresolved city or country reference.

Fixtures live under `supabase/seed` or a dedicated Edge Function test-fixture directory, never in
schema sources or generated migrations. Sanitized approved-API responses become offline fixtures
only after removing credentials, headers, prohibited data, and unbounded records.

## Error Contract

The ingestion transport normalizes failures to:

- `ERR_INGESTION_UNAUTHORIZED`
- `ERR_INGESTION_INVALID_REQUEST`
- `ERR_INGESTION_SOURCE_NOT_ALLOWED`
- `ERR_INGESTION_BATCH_DUPLICATE`
- `ERR_INGESTION_VALIDATION_FAILED`
- `ERR_INGESTION_PUBLISH_FAILED`

The web read boundary normalizes dependency failures to:

- `ERR_CITY_PAGE_UNAVAILABLE`
- `ERR_AIRPORT_PAGE_UNAVAILABLE`

Responses use the existing shared envelope. Logs contain request ID, action, status, processed
timestamp, and stable error code, but not provider payloads or sensitive caller data.

## Security

- Only a configured worker secret or verified local operator may invoke ingestion.
- Provider selection is restricted to configured source codes and modes.
- Approved provider URLs and credentials are server-owned configuration.
- Rate limiting keys combine worker identity with a normalized, hashed IP value.
- Raw and admin tables have no anonymous or authenticated public access.
- Public clients retain read-only access to eligible canonical models and no domain writes.
- Privileged functions use an explicit `search_path` and are not placed in exposed schemas.
- No service-role or secret variable uses a `NEXT_PUBLIC_*` name.
- Security guard tests scan bundles, environment examples, grants, and Edge logs for boundary
  violations.

## Testing Strategy

Behavior changes follow test-first development. Each test must be observed failing for the intended
missing behavior before implementation.

Backend evidence includes:

- SQL contract tests for all four tables, constraints, RLS or schema isolation, grants, and
  privileged functions;
- SQL end-to-end tests for valid publication, invalid-batch rollback, duplicate replay, and
  null-preserving unknown values;
- adapter unit tests for the mock fixture and sanitized real fixture;
- Edge handler tests for authentication, request bounds, source allowlist, idempotency, rate limits,
  and normalized errors;
- deterministic migration regeneration and a local database rebuild from migration plus seed.

Web evidence includes:

- shared transport and environment contract tests for both city and airport repositories;
- DTO tests for malformed and valid envelopes;
- tests for not-found, bounded dependency errors, cache-version changes, metadata, canonical URLs,
  and `noindex`;
- homepage inventory and broken-link contract tests;
- desktop and mobile browser smoke checks for homepage, city, airport, filters, and route-map
  fallback.

The final local command sequence covers formatting, linting, TypeScript, Deno formatting/check/tests,
SQL contract and end-to-end tests, security guards, and the Next.js production build.

## Acceptance and Source State

The acceptance report maps automated or documented smoke evidence to all 12 P0A capabilities. A
capability may be marked incomplete only when a real cloud dependency is demonstrated; local logic,
data, build, and test failures are not deferrable.

The approved-API smoke test remains opt-in and non-blocking for offline CI, but its successful bounded
run is required for full P0A acceptance. If credentials or owner approval are unavailable, capability
5 is the only anticipated 11/12 exception.

The P0B source state is the exact pair of backend and web commit SHAs recorded after P0A acceptance.
Because repository policy requires explicit permission, implementation will not commit, push, deploy,
or connect an external provider automatically.

## Explicit Non-Goals

- Production-scale diffs, approvals, retention, or scheduled ingestion.
- Real route or schedule ingestion.
- Redis, durable queues, production CDN behavior, or monitoring.
- Remote deployment or P0B environment setup.
- Enabling production or SEO eligibility for P0 provider data.
