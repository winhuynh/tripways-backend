# Tripways Backend Foundation BRD

**Document status:** Approved for implementation planning  
**Version:** 1.0  
**Date:** 2026-07-14  
**Product:** Tripways / Global Travel Graph  
**Scope:** Production-minded backend foundation for the flight-first MVP

## 1. Executive Summary

Tripways is a travel graph data product that helps users explore global flight networks through
airports, cities, airlines, countries, and directional routes. The initial backend must establish a
production-ready foundation on Supabase without claiming live prices, live availability, or route
truth unsupported by licensed data.

The backend will use a hybrid monorepo architecture:

- Supabase Postgres owns normalized domain data, graph projections, publish rules, and routing
  queries.
- Next.js Route Handlers expose cacheable public read APIs for search, entity pages, routes, and
  sitemap data.
- Supabase Edge Functions handle privileged ingestion, analytics capture, and affiliate click
  tracking.
- Raw provider data remains inaccessible in private schemas.

The first implementation is schema-first across the complete MVP domain. It defines the core data
model and API boundaries while excluding speculative fare, account, payment, AI, and multimodal
features.

## 2. Business Objective

Build a trustworthy backend foundation that enables Tripways to:

- Import and normalize airport, city, country, airline, and route data.
- Model transportation data as a graph while delivering flight-first functionality.
- Discover direct and one-stop flight routes.
- Generate useful, SEO-safe airport, city, route, airline, and country pages.
- Track data source rights, freshness, confidence, ingestion state, and publish history.
- Capture product analytics and affiliate outbound clicks safely.
- Add a licensed production schedule provider without restructuring the core system.

## 3. Product Principles

1. **Data first:** Transportation graph data is the core product asset.
2. **Graph first:** The model supports future transport node and edge types without implementing
   non-flight modes in the MVP.
3. **Source first:** Every published route has source, license, freshness, status, and confidence
   metadata.
4. **Safe claims:** The product does not claim live availability, guaranteed routes, or cheapest
   prices without an appropriate licensed source.
5. **Private by default:** Raw provider payloads and internal operations are not exposed through the
   public Data API.
6. **YAGNI:** The foundation includes only the abstractions and dependencies required by the MVP.

## 4. Scope

### 4.1 Included

- A pnpm workspace monorepo named `tripways-backend`.
- A minimal Next.js API application under `apps/api`.
- Supabase local configuration, migrations, maintainable SQL sources, seed data, and Edge Functions.
- Shared runtime request and response contracts.
- Normalized country, city, airport, airline, route, graph, source, affiliate, and analytics schemas.
- Data ingestion batches, validation results, diffs, publish runs, and rollback-safe publishing.
- A deterministic local fixture covering representative direct and one-stop routes.
- A manually invoked OurAirports importer.
- A production provider ingestion contract and a sample adapter using non-production fixture data.
- Public APIs for health, search, airports, cities, routes, airlines, countries, and sitemap data.
- Edge endpoints for ingestion, analytics events, and affiliate click events.
- RLS, privilege, schema-exposure, and data-license guardrails.
- Format, lint, typecheck, SQL, contract, integration, API, and security checks.
- Adapted Tripways workflow and coding requirement documents based on `slofi-backend`.

### 4.2 Excluded

- Live fare or availability search.
- Booking, payment, user accounts, subscriptions, or premium features.
- AI itinerary planning.
- Train, ferry, cruise, bus, or walking-transfer ingestion and routing.
- Two-stop or three-stop route discovery.
- Live delay and flight status.
- A concrete OAG, Cirium, or other licensed provider adapter before a provider is selected and its
  contract is reviewed.
- OpenFlights data in local fixtures, production data, APIs, or SEO output.
- Remote Supabase project creation, linking, deployment, or production resource provisioning.
- Redis or Upstash until measured cache requirements justify it.
- Future fare tables before provider display, storage, and cache rights are confirmed.

## 5. Success Criteria

The foundation is accepted when:

- A new developer can install dependencies and start the local stack from documented commands.
- Migrations and deterministic seed data rebuild the local database successfully.
- The sample ingestion flow validates and transactionally publishes fixture data.
- The OurAirports importer parses a known fixture offline and supports an explicit manual download
  command for real source files.
- Search and all planned public entity endpoints return contract-valid responses.
- Direct and one-stop route queries return deterministic, correctly ranked results.
- Every published route includes source, status, confidence, and verification timestamps.
- Development fixture data cannot become production or SEO-indexable data.
- Invalid or unlicensed ingestion cannot replace the currently published dataset.
- Empty, historical, development-only, or low-confidence entities and routes are excluded from the
  sitemap source.
- Every exposed table has RLS enabled and no raw provider data is accessible to public roles.
- API responses do not claim live prices or live availability.
- Format, lint, typecheck, build, test, and security guard commands pass.

## 6. Repository Architecture

```text
tripways-backend/
├── apps/
│   └── api/
│       ├── src/app/api/
│       │   ├── health/
│       │   ├── search/
│       │   ├── airports/[slug]/
│       │   ├── cities/[slug]/
│       │   ├── routes/
│       │   ├── routes/[slug]/
│       │   ├── airlines/[slug]/
│       │   ├── countries/[slug]/
│       │   └── sitemap/
│       └── src/lib/
├── packages/
│   └── contracts/
├── supabase/
│   ├── functions/
│   │   ├── _shared/
│   │   └── v1/
│   │       ├── ingestion/
│   │       ├── events/
│   │       └── affiliate-click/
│   ├── migrations/
│   ├── sql_src/
│   ├── seed/
│   └── config.toml
├── scripts/
│   ├── import-ourairports/
│   └── checks/
├── docs/
│   ├── architecture/
│   ├── brd/
│   ├── data-sources/
│   └── runbooks/
├── package.json
└── pnpm-workspace.yaml
```

### 6.1 Component Boundaries

- **Postgres/RPC:** Owns graph queries, publish validation, indexability, data versioning, and
  domain invariants.
- **Next.js API:** Owns HTTP validation, public response contracts, cache headers, and request
  tracing. It does not duplicate SQL business rules.
- **Supabase Edge Functions:** Own privileged or secret-bearing workflows. Edge handlers remain thin
  orchestrators over shared validation and database operations.
- **Contracts package:** Contains only request, response, event, and ingestion contracts shared by
  at least two active consumers.
- **Importer scripts:** Parse source-specific data into canonical ingestion inputs. They do not write
  directly to published tables.

## 7. Schema Ownership

### 7.1 `private`

Contains raw provider data and staging records, including:

- `raw_import_batches`
- `raw_airports`
- `raw_airlines`
- `raw_routes`
- Provider payload references and row-level validation failures

The schema is not exposed through the Supabase Data API and grants no access to public client roles.

### 7.2 `admin`

Contains operational and license state, including:

- `data_sources`
- `ingestion_runs`
- `ingestion_issues`
- `publish_runs`

Data source records explicitly store whether production use, SEO display, caching, and derived data
are allowed. Operational records track received, accepted, rejected, published, and changed row
counts.

### 7.3 `public`

Contains normalized, read-safe domain data:

- `countries`
- `cities`
- `airports`
- `airlines`
- `transport_nodes`
- `transport_operators`
- `transport_edges`
- `flight_routes`
- `affiliate_partners`
- `affiliate_links`

Every public table has RLS enabled before it becomes accessible. Public clients receive no write
policy. Read access is limited to safe rows and RPC/read-model contracts.

### 7.4 `analytics`

Contains append-only event sinks:

- `events`
- `affiliate_click_events`

The schema is not exposed through the public Data API. Writes occur through validated Edge
Functions.

## 8. Core Data Rules

- Internal relational keys use UUIDs.
- IATA, ICAO, ISO, slug, and provider identifiers use conditional unique constraints appropriate to
  their nullability and source scope.
- Routes are directional; origin and destination cannot match.
- `flight_routes` is the normalized flight source of truth.
- `transport_edges` is a graph projection derived from `flight_routes` and is not independently
  editable.
- A route cannot publish without a resolvable origin, destination, and approved source.
- An unresolved operator is represented explicitly and cannot silently become a known airline.
- Missing frequency is unknown, not zero.
- Missing seasonality is unknown, not year-round.
- Route status is one of `verified_active`, `likely_active`, `seasonal`, `unknown`, `historical`,
  `inactive`, or `low_confidence`.
- Development fixture records carry an environment scope that prevents production and SEO publish.
- Public route data retains lineage to a source without exposing confidential license notes or raw
  provider payloads.

## 9. Ingestion and Publish Flow

```text
Source file or provider payload
→ create immutable raw batch
→ validate source schema and snapshot identity
→ normalize codes and canonical fields
→ resolve countries, cities, airports, airlines, and routes
→ validate domain and license rules
→ transactionally publish normalized rows
→ rebuild graph projections and indexable read models
→ increment data version
→ record publish diff, freshness, and result
```

Publish is atomic. If validation fails, license flags do not allow the intended use, or an invariant
is violated, the transaction is rolled back and the previously published dataset remains active.
The same batch or idempotency key cannot publish twice.

### 9.1 Source Strategy

- OurAirports supplies airport, country, region, coordinate, and airport metadata.
- A deterministic hand-authored fixture supplies local and CI route scenarios.
- OpenFlights is not used.
- The production schedule provider is represented by a canonical ingestion contract and sample
  adapter only. A real adapter is implemented after provider selection and contract review.

## 10. API Requirements

### 10.1 Public Next.js Route Handlers

- `GET /api/health`
- `GET /api/search?q=&type=&limit=`
- `GET /api/airports/:slug`
- `GET /api/cities/:slug`
- `GET /api/routes?from=&to=`
- `GET /api/routes/:from-to-:to`
- `GET /api/airlines/:slug`
- `GET /api/countries/:slug`
- `GET /api/sitemap`

The route slug uses canonical origin and destination codes separated by `-`. Canonical redirect
behavior is applied when user input differs in case or resolves from an alias.

### 10.2 Privileged Edge Functions

- `POST /functions/v1/ingestion`
- `POST /functions/v1/events`
- `POST /functions/v1/affiliate-click`

Ingestion requires a worker identity or secret and an idempotency key. Event endpoints accept only
allowlisted event names, bounded payloads, and validated identifiers.

### 10.3 Response Envelope

Successful and failed responses share a stable envelope:

```json
{
  "data": {},
  "meta": {
    "request_id": "uuid",
    "generated_at": "ISO-8601",
    "freshness": {},
    "cache": {
      "status": "HIT|MISS|BYPASS",
      "max_age_seconds": 300
    }
  },
  "error": null
}
```

Errors use stable codes such as `ERR_INVALID_INPUT`, `ERR_NOT_FOUND`, `ERR_RATE_LIMITED`,
`ERR_DATA_NOT_PUBLISHED`, and `ERR_INTERNAL`. Raw database and provider errors are never returned.

## 11. Route Discovery

The MVP route finder supports:

- Direct routes.
- One-stop routes.

Results rank by:

1. Direct over connected routes.
2. Fewer stops.
3. Higher confidence.
4. Higher known frequency.
5. Same airline or alliance when that data is known.
6. Connection-airport quality when that data is available.
7. Lower geographic detour.

Unknown ranking inputs remain neutral and are not converted to favorable defaults. Historical,
inactive, development-only, and disallowed routes do not appear in production results.

## 12. SEO and Indexability

The sitemap reads a precomputed indexable URL set rather than executing heavy graph queries per
request.

An entity or route is indexable only when:

- It has useful interactive graph data.
- Its source allows production and SEO use.
- It is not development-only, historical, empty, or low-confidence.
- Its freshness and confidence meet the published threshold.

Pages with only text, no route data, or unverifiable routes are excluded. API copy must use cautious
language such as "known scheduled route", "likely active route", or "data not recently verified".

## 13. Caching and Freshness

- Next.js returns CDN-compatible HTTP cache headers for public read endpoints.
- Search uses a short TTL.
- Entity and route read models use a moderate TTL.
- Sitemap data is precomputed and cached separately.
- Cache identity includes every normalized input that can affect the response.
- A successful publish increments `data_version`; cached responses and keys include that version so
  obsolete data expires without per-key invalidation.
- Redis and Upstash are intentionally excluded until measured needs exceed HTTP/CDN caching.
- Every read response returns generated and source freshness metadata.

## 14. Analytics and Affiliate Tracking

The foundation recognizes allowlisted events for:

- Search and no-result search.
- Filter and map interactions.
- Direct destination and one-stop result clicks.
- SEO landing-page interaction.
- Share actions.
- Affiliate outbound clicks.

Event payloads are bounded and versioned. Logs and persisted properties exclude authorization
headers, secrets, full IP addresses, and unbounded arbitrary JSON. Affiliate clicks validate active
partners and links before recording the event.

## 15. Security Requirements

- No secret, token, or service-role key is committed or included in a public client bundle.
- Every exposed table has RLS enabled and an explicit access model.
- Private, admin, and analytics schemas are omitted from the Data API schema list.
- Views exposed to client roles use `security_invoker = true` when applicable.
- `security definer` functions are not placed in exposed schemas.
- Privileged functions use explicit `search_path` and minimal grants.
- Input validation occurs at HTTP/Edge boundaries and domain invariants are enforced again in SQL.
- Ingestion is authenticated, authorized, rate-limited, and idempotent.
- Analytics and affiliate endpoints are rate-limited by an appropriate anonymous session and network
  identity strategy.
- Structured logs never contain raw provider payloads, secrets, tokens, or unnecessary personal
  data.

## 16. Testing and Quality Gates

### 16.1 Automated Tests

- Contract tests for validation, envelopes, metadata, and error codes.
- SQL tests for constraints, grants, RLS, license gating, fixture isolation, and indexability.
- Import tests for canonical mapping, invalid rows, duplicate rows, and snapshot identity.
- Integration tests for raw batch through transactional publish.
- Route tests for direct, one-stop, directionality, duplicates, unknown values, ordering, and
  exclusions.
- API integration tests against the local Supabase database for critical read flows.
- Security guards for public RLS coverage, schema exposure, privileged functions, and grants.
- OurAirports parser tests using a small repository fixture without network access.

### 16.2 CI Order

1. Format, lint, and typecheck.
2. Unit and contract tests.
3. Start the local Supabase stack.
4. Rebuild the database from migrations and deterministic seed data.
5. Run SQL, security, ingestion, routing, and API integration tests.
6. Build the Next.js API application.
7. Verify migration and maintainable SQL-source consistency.

## 17. Observability and Operations

Structured logs include:

- `request_id`
- `action`
- `status`
- `processed_at`
- `error_code`
- Relevant non-sensitive source, batch, and publish identifiers

Each ingestion run records input, accepted, rejected, published, and changed row counts. The repo
includes runbooks for local setup, database reset, OurAirports import, migration generation,
provider-adapter development, and security verification.

The foundation does not link or deploy a remote Supabase project. Remote environment setup remains
an explicit later operation requiring project identifiers, credentials, and user authorization.

## 18. Engineering Rules

The repo includes an adapted `docs/codex_work_rules.md` derived from `slofi-backend` and a matching
`docs/tripways-backend-coding-requirements.md`.

The adapted rules retain:

- Review-first decision trace.
- Scope safety and preservation of user changes.
- No automatic commits.
- English code comments and consistent SQL/TypeScript formatting.
- Thin transport layers with SQL/RPC business ownership.
- Stable error codes and structured logging.
- RLS, secrets, migration, and service-role safety.
- TDD for behavior and runnable checks for non-trivial logic.
- Senior minimalism and YAGNI.

Slofi-specific wallet, mobile-only, RevenueCat, AI, and Redis freshness-catalog requirements are not
copied because they do not apply to Tripways.

## 19. Key Decisions

| Decision            | Selected option                                 | Reason                                                                     |
| ------------------- | ----------------------------------------------- | -------------------------------------------------------------------------- |
| Backend boundary    | Hybrid Next.js + Supabase                       | Supports SEO/cacheable reads and isolates privileged workflows.            |
| Repository layout   | pnpm monorepo                                   | Provides strict dependency management and clean package boundaries.        |
| Foundation depth    | Schema-first full MVP                           | Establishes the full domain and contract surface before feature iteration. |
| Local data          | Deterministic fixture plus OurAirports importer | Keeps CI reliable while validating a real base-data source.                |
| Production provider | Canonical contract plus sample adapter          | Avoids guessing a licensed provider format before selection.               |
| Public data access  | Next.js/RPC read boundary                       | Reduces frontend coupling and protects provider data.                      |
| Cache               | HTTP/CDN plus `data_version`                    | Meets current needs without speculative Redis infrastructure.              |
| OpenFlights         | Not used                                        | Prevents historical data from being mistaken for route truth.              |
| Workflow rules      | Adapted from `slofi-backend`                    | Preserves proven quality rules without unrelated domain requirements.      |

## 20. Open Product Decisions Not Blocking the Foundation

- Licensed production schedule provider selection and contract terms.
- Global launch versus selected initial markets.
- Initial affiliate partner priority.
- Production cache/CDN provider and measured TTL tuning.
- Future fare provider and whether price indication becomes premium.

These decisions are intentionally deferred because the foundation provides explicit contracts and
boundaries without depending on a specific answer.

## 21. Implementation Handoff

The next step is a file-by-file implementation plan covering repository initialization, tests,
Supabase schema, ingestion, graph queries, APIs, security guards, documentation, and verification.
No remote deployment or commit is authorized by this BRD.
