# Provider-Ready Page Data Foundation Design

## 1. Goal

Make the local TripWays backend a complete, provider-neutral data foundation for the current Homepage, City Hub, Airport Hub, and Route Page concepts. The repository must prove all ingestion, publication, graph, pSEO, and API contracts end to end with deterministic fixtures. Replacing a fixture source with an approved production provider must require only a provider adapter, source configuration, credentials, and operational scheduling—not a redesign of canonical tables, page payloads, or frontend-facing APIs.

This scope does not build UI, affiliate redirects, live booking offers, production deployment, or provider credentials.

## 2. Delivery strategy

The work is delivered as one foundation release and one regenerated migration set. Source SQL remains split by table and function under `supabase/sql_src` according to repository rules; the migration generator produces the deterministic release output.

The release is internally modular so schema and behavior remain reviewable:

1. Provider rights and ingestion contracts.
2. Canonical place, airport, airline, route, and recurring-service data.
3. Bounded zero-to-three-stop route graph generation.
4. Provider-ready route price estimates.
5. Homepage, City Hub, Airport Hub, and Route Page read models.
6. Versioned RPC and Edge Function read boundaries.
7. Sitemap, freshness, and indexability gates.
8. Deterministic fixtures and end-to-end verification.

## 3. Architectural boundaries

### 3.1 PostgreSQL

PostgreSQL owns:

- Canonical domain invariants.
- Source-rights and publication eligibility.
- Atomic publication and data versions.
- Route compatibility, graph expansion, ranking, and facets.
- pSEO publication, freshness, and indexability.
- Provider-neutral page read models.

### 3.2 Edge Functions

Edge Functions remain thin privileged transports. They parse and validate a stable request, select the configured provider adapter only for ingestion/import operations, call PostgreSQL RPCs, normalize safe errors, and return stable envelopes.

Page-query Edge Functions never call a schedule or price provider directly. They read only published canonical/read-model data.

### 3.3 Provider adapters

Each source implements a provider-neutral adapter contract. Domain code, SQL, read APIs, fixtures, and frontend contracts never use provider-specific field names.

The required adapter operations are:

```ts
interface BaseDataProviderAdapter {
  fetchBatch(input: BaseDataFetchInput): Promise<CanonicalBaseDataBatch>;
}

interface ScheduleProviderAdapter {
  fetchBatch(input: ScheduleFetchInput): Promise<CanonicalScheduleBatch>;
}

interface PriceEstimateProviderAdapter {
  fetchBatch(
    input: PriceEstimateFetchInput,
  ): Promise<CanonicalPriceEstimateBatch>;
}
```

Adapter selection is configuration-driven through a bounded registry:

```ts
const providerAdapters = {
  fixture: fixtureProviderAdapter,
  approved_api: approvedApiProviderAdapter,
} as const;
```

Changing a source means changing `provider_code` configuration and credentials. Public RPC names, request DTOs, response DTOs, canonical database fields, and page URLs remain unchanged.

## 4. Source rights and provenance

Extend `admin.data_sources` with:

- `storage_allowed`
- `retention_days`
- `production_display_allowed`
- `cache_allowed`
- `max_cache_ttl_seconds`
- `attribution_text`
- `attribution_url`
- `rights_effective_at`
- `rights_expires_at`
- Existing production, SEO, and derived-data permissions

Every canonical schedule, price estimate, and derived page record must retain source identity, source-record identity, verification/freshness time, confidence, and the publication data version.

Publication rejects a batch when its source rights do not authorize the target use. Development fixtures are always non-production and non-indexable.

## 5. Ingestion model

### 5.1 Record types

Extend private raw ingestion to accept:

- `country`
- `city`
- `place_alias`
- `metro_area`
- `airport`
- `airport_terminal`
- `airline`
- `flight_route`
- `flight_service`
- `route_price_estimate`
- `city_fact`
- `airport_facility`
- `airport_fact`
- `page_editorial_content`

Raw provider payloads remain in private schema. Public schemas contain only validated canonical data.

### 5.2 Publication

A publication transaction performs:

1. Batch/idempotency validation.
2. Source-rights validation.
3. Referential resolution and canonical validation.
4. Canonical entity publication.
5. Explicit deactivation according to provider rules.
6. Route-option rebuild for affected markets.
7. Page read-model rebuild for affected entities.
8. Freshness and indexability calculation.
9. New data-version creation.
10. Publish-diff and operational outcome recording.

Any failure rolls back the complete new version. The previously published version remains available.

## 6. Canonical place and airport discovery

Add provider-neutral structures for:

- Metro areas such as London or New York multi-airport groups.
- Localized place aliases and normalized search terms.
- Nearby-airport relationships with distance and relevance.
- Airport terminals.
- Terminal-airline relationships with validity and provenance.

Create a homepage place-search read model supporting city, airport, metro, IATA, localized alias, country, and nearby-airport discovery. Search ranking is deterministic and database-owned.

## 7. Multi-stop route graph

### 7.1 Route shape

Generalize `route_options` from zero/one stop to zero through three stops.

Each option stores ordered arrays for:

- `service_ids`
- `flight_route_ids`
- `origin_airport_ids`
- `destination_airport_ids`
- `connection_airport_ids`
- `operating_airline_ids`
- `marketing_airline_ids`
- Per-leg departure and arrival times
- Per-leg durations
- Inter-leg layovers

The arrays must have consistent cardinality based on `stop_count`.

### 7.2 Graph bounds

The graph generator supports a configured maximum of three stops and enforces:

- No repeated airport within an itinerary.
- No return to the origin city/airport.
- Configurable minimum and maximum layover.
- Schedule validity intersection.
- Operating-day compatibility and day offsets.
- Configurable maximum total duration.
- Configurable maximum candidate expansion per origin/market.
- Confidence and source-rights thresholds.
- Deterministic pruning before materialization.

The default public route-search limit is three stops. Callers cannot request an unbounded graph search.

### 7.3 Ranking

Stable ranking uses:

1. Fewer stops.
2. Lower total duration.
3. Better connection quality.
4. Higher confidence.
5. Higher known frequency.
6. Stable UUID tie-breaker.

Unknown values remain unknown and are never converted to zero, false, or year-round.

## 8. Route price estimates

Add `public.route_price_estimates` as a provider-ready derived-data table. It is separate from live offers and never claims current seat availability.

Required dimensions:

- Origin/destination city and optional airport pair.
- Trip type: one-way or return.
- Cabin.
- Stop bucket: direct, one stop, two stops, three stops, or any.
- Optional airline.
- Optional baggage inclusion state.
- Minimum and maximum amount.
- Currency.
- Estimate method and sample window.
- Observation/sample count when rights permit.
- Source, source-record identity, confidence, freshness, `valid_until`, and data version.
- Status and publication eligibility.

Price estimates are returned only when:

- Source derived-data and display rights allow it.
- Currency and bounds are valid.
- Freshness and `valid_until` pass.
- Confidence/sample rules pass.
- The page version and estimate version are compatible.

Expired or missing estimates return `null` with a stable availability reason. They never become zero.

## 9. Page data contracts

### 9.1 Homepage

Provide stable read contracts for:

- Place autocomplete.
- Featured/popular origins.
- Routes from a selected origin.
- Interactive route-map nodes and edges.
- Direct/one/two/three-stop filters.
- Duration, airline, connection-airport, departure-window, and estimated-price filters.

Homepage reads stored discovery data only. Dated live flight search remains outside this release.

### 9.2 City Hub

Extend the City Hub payload with:

- Direct-route estimated price ranges and price facets.
- Structured city facts: currency, languages, timezone/DST, local transport, entry-guidance summary, climate summary, travel tips, and cited source metadata.
- Airport-to-centre facts and airport comparisons.
- Destination rows linking to registered Route Pages.
- Explicit unknown/unavailable states.

Editorial/legal facts require primary source URL, verification time, validity period where applicable, review status, and locale.

### 9.3 Airport Hub

Extend the Airport Hub payload with:

- Estimated price ranges and price facets for route rows.
- Terminals.
- Terminal-airline relationships.
- Structured facilities and categories.
- Access, parking, lounges, notices, and FAQ.
- Airport facts with citation and freshness.
- Nearby airport alternatives.
- Route Page links.

The page never claims live departures, gates, counters, delays, security waits, or live parking availability.

### 9.4 Route Page

Add a complete Route Page pSEO domain:

- `route_pages`
- `route_page_faqs`
- `route_page_airport_comparisons`
- `route_page_travel_facts`
- `route_page_editorial_sections`
- Route-related internal-link clusters

The read payload includes:

- Origin/destination city and airport context.
- Direct and indirect zero-to-three-stop options.
- Airlines, connection hubs, durations, layovers, schedules, day offsets, and freshness.
- Price estimates and price facets when eligible.
- Route map.
- Airport comparison.
- Indicative schedule/timezone facts.
- Reviewed travel-preparation content.
- Alternative and reverse routes.
- FAQ, methodology, disclosure, canonical, publication, and indexability metadata.

Stored route data cannot assert self-transfer, through baggage, fare rules, or live availability unless a future provider-specific fact has been normalized into a separately approved canonical contract.

## 10. API and source-switching contract

Add stable Edge Function/API operations for:

```text
homepage-page-query
city-page-query
airport-page-query
route-page-query
route-discovery-query
sitemap-query
ingestion-base-data
ingestion-schedule-data
ingestion-price-estimates
```

All read responses use the shared envelope:

```json
{
  "data": {},
  "meta": {
    "request_id": "uuid",
    "generated_at": "ISO-8601",
    "data_version": "uuid",
    "freshness": {},
    "cache": {
      "status": "BYPASS",
      "max_age_seconds": 300
    }
  },
  "error": null
}
```

Provider identity may appear only in server-side operational metadata or approved attribution fields. Provider payloads, tokens, credentials, internal IDs, and errors never enter public responses.

Switching providers must not change:

- Public endpoint names.
- RPC names.
- Request fields.
- Page payload fields.
- Canonical IDs and URL identities.
- Frontend code.

## 11. Sitemap and indexability

Database-owned indexability requires:

- Production and SEO/display rights.
- Required route depth.
- Freshness threshold.
- Confidence threshold.
- Reviewed editorial content.
- Unique canonical identity.
- Valid data version.
- No fixture lineage.

Sitemap reads only published, indexable `pseo_pages` records. Filtered URLs are non-indexable and canonicalize to their base page.

## 12. Error and stale-data behavior

Stable errors distinguish:

- Invalid request.
- Page not found.
- No published data.
- Data unavailable.
- Provider ingestion unavailable.
- Contract violation.

Provider ingestion failure does not remove the previously published version. Stale data follows page-type freshness policy: serve with explicit freshness metadata, noindex, or unavailable state depending on threshold.

“No data” is never treated as “no route.”

## 13. Local fixtures

Fixtures must prove:

- Multi-airport cities.
- Place aliases and metro groups.
- Direct, one-, two-, and three-stop routes.
- Repeated-node and invalid-connection rejection.
- Operating-day and day-offset compatibility.
- Source-rights rejection.
- Valid, missing, expired, stale, and unlicensed price estimates.
- City facts with citations.
- Airport terminals and facilities.
- Homepage discovery payload.
- City, Airport, and Route Page payloads.
- Published versus draft/stale/non-indexable pages.
- Sitemap exclusion of all fixture pages.

Every fixture source remains `development_fixture`, `production_allowed = false`, and `seo_allowed = false`.

## 14. Verification requirements

The release is complete only when these pass from a clean local reset:

- Migration regeneration determinism.
- Database reset and seed.
- Schema, constraint, index, RLS, and privilege tests.
- Source-rights matrix tests.
- Adapter normalization tests.
- Atomic publication and rollback tests.
- Zero-to-three-stop graph correctness and pruning tests.
- Price-estimate eligibility/freshness tests.
- Homepage/City/Airport/Route RPC contract tests.
- Edge request/response/error tests.
- Sitemap and indexability tests.
- Format, lint, typecheck, Deno tests, and repository verification.

Performance fixtures must assert bounded graph generation and indexed page reads; they are not substitutes for production load tests.

## 15. Explicit exclusions

- UI implementation.
- Affiliate partner/program/redirect/event schemas.
- Live offer, seat availability, booking, or checkout.
- Provider credentials.
- Production deployment or remote linking.
- Production indexability enablement.
- Provider-specific logic inside canonical SQL or public read contracts.

## 16. Completion statement

The foundation is considered provider-ready when local fixtures pass end to end and adding an approved real source requires only adapter mapping, configuration, credentials, and operations. If any real-provider onboarding would require changing canonical page payloads or frontend-facing APIs, this design has not been satisfied.
