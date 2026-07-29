# Airport pSEO Backend Design

## Goal

Add airport pSEO pages that prioritize direct flight routes and provide a small, reviewed layer for
airport access, parking, lounges, and essential notices. Extend city pages so outbound and inbound
city landing pages can link to the same airport entities and read the same route truth.

The implementation must keep one route eligibility pipeline, avoid duplicated read models, and
return frontend-ready payloads through bounded RPCs.

## Product boundary

Airport pages answer:

- Where can a traveler fly directly from this airport?
- Which cities and airlines fly directly to this airport?
- How can a traveler get to or from the airport?
- What general parking and lounge options are available?
- Which small number of reviewed notices materially affect trip planning?

Airport pages do not own live departures, arrivals, fares, availability, gates, check-in counters,
terminal maps, security waits, shops, restaurants, or operational alerts.

## Architecture decisions

### One normalized route truth

`public.flight_routes` and `public.flight_services` remain the normalized route and schedule truth.
No airport-specific route source table is added.

The current `public.city_direct_routes` projection is renamed to
`public.pseo_direct_routes`. It remains rebuildable and contains the scalar dimensions required by
both city and airport pages. The projection adds `origin_country_id` so inbound and outbound reads
are symmetric.

City pages select the projection by city ID. Airport pages select it by airport ID. Route
eligibility, confidence, source rights, freshness, and `data_version` are therefore calculated once.

### Direct reads without unnecessary layers

Public page RPCs read:

1. normalized entity tables for identity;
2. `pseo_direct_routes` for route facts;
3. one page table for reviewed metadata and cached page facts;
4. focused child tables for reviewed airport guidance;
5. `pseo_internal_links` for registered semantic links.

No SQL views, generic repositories, polymorphic content tables, or airport route-copy tables are
introduced. Private functions are limited to request identity resolution and logic reused by more
than one public RPC.

### Separate facts from reviewed content

Route counts, airlines, durations, freshness, and rankings are derived during refresh. SEO copy,
access guidance, parking summaries, lounge summaries, notices, and FAQs are reviewed content with
their own source and verification metadata.

Normalized `public.airports` is not expanded with locale-specific or operational guidance.

## Shared pSEO route projection

Rename `public.city_direct_routes` to `public.pseo_direct_routes` and retain its current columns,
constraints, route lineage, and versioning. Add:

```text
origin_country_id UUID NOT NULL REFERENCES public.countries (id)
```

The projection stores one eligible directional `flight_route` per `data_version`. Existing city
destination summaries aggregate from it.

Required indexes:

```text
(origin_city_id, data_version, destination_city_id)
(destination_city_id, data_version, origin_city_id)
(origin_airport_id, data_version, destination_airport_id)
(destination_airport_id, data_version, origin_airport_id)
(origin_airport_id, data_version, operating_airline_id)
(destination_airport_id, data_version, operating_airline_id)
(origin_airport_id, data_version, destination_country_id)
(destination_airport_id, data_version, origin_country_id)
(origin_airport_id, data_version, shortest_duration_minutes)
```

The previous city-specific indexes are removed when an equivalent shared index supersedes them.
Every city pSEO function is updated to read `pseo_direct_routes`; its existing public response
contract changes only where the city direction design below requires it.

## City page extension

### Directional page identity

`public.city_pages` gains:

```text
route_direction TEXT NOT NULL DEFAULT 'outbound'
```

Allowed values are `outbound` and `inbound`. The identity becomes:

```text
UNIQUE (city_id, locale, route_direction)
UNIQUE (canonical_slug, locale, route_direction)
```

`pseo_pages.entity_key` uses:

```text
bangkok:outbound
bangkok:inbound
```

Canonical paths remain explicit:

```text
/flights-from/bangkok
/flights-to/bangkok
```

This avoids separate city schemas and lets the same RPC contract serve both directions.

### Direction-neutral derived fields

Origin-only cached facts are renamed:

```text
direct_destination_count -> direct_counterpart_city_count
direct_country_count     -> direct_counterpart_country_count
```

The following fields remain because their meaning is valid in either direction:

```text
airport_count
airline_count
shortest_route_minutes
longest_route_minutes
source_freshness_at
data_version
```

For `outbound`, counterpart facts describe destinations. For `inbound`, they describe origins.
This prevents duplicated inbound/outbound count columns that can become inconsistent.

`private.parse_city_page_identity`, `private.resolve_city_page_context`, and city public RPC inputs
accept `route_direction`, defaulting to `outbound` for backward compatibility. The resolved page
context includes the direction. City route filters select the correct side of
`pseo_direct_routes`.

`city_destination_summaries` is retained for outbound featured destination cards. An inbound
summary table is not added initially. Inbound city pages aggregate bounded featured origins
directly from `pseo_direct_routes`; a stored inbound summary is justified only by measured query
cost.

## Airport page schema

### `public.airport_pages`

One row represents one localized airport landing page:

```text
id                         UUID
pseo_page_id               UUID UNIQUE REFERENCES public.pseo_pages
airport_id                 UUID REFERENCES public.airports
locale                     TEXT
canonical_slug             TEXT
h1                         TEXT
subheadline                TEXT
seo_title                  TEXT
meta_description           TEXT
og_title                   TEXT
og_description             TEXT
og_image_path              TEXT NULL
intro                      TEXT
route_summary              TEXT
access_summary             TEXT NULL
parking_summary            TEXT NULL
lounge_summary             TEXT NULL
outbound_destination_count INTEGER
outbound_country_count     INTEGER
inbound_origin_count       INTEGER
inbound_country_count      INTEGER
airline_count              INTEGER
shortest_route_minutes     INTEGER NULL
longest_route_minutes      INTEGER NULL
status                     TEXT
is_indexable               BOOLEAN
noindex_reason             TEXT NULL
content_reviewed_at        TIMESTAMPTZ NULL
source_freshness_at        TIMESTAMPTZ NULL
data_version               UUID NULL
generated_at               TIMESTAMPTZ
published_at               TIMESTAMPTZ NULL
created_at                 TIMESTAMPTZ
updated_at                 TIMESTAMPTZ
```

Identity constraints:

```text
UNIQUE (airport_id, locale)
UNIQUE (canonical_slug, locale)
```

Count, status, content trimming, locale, slug, duration, and indexability checks follow the
established `city_pages` pattern. All page and child tables enable RLS, grant no access to `anon`
or `authenticated`, and grant only required operations to `service_role`.

The page registry uses:

```text
page_type      = airport
entity_key     = bkk
canonical_path = /airports/suvarnabhumi-bkk
```

Only airports with an IATA code are eligible for the initial airport page type.

### `public.airport_access_options`

Stores reviewed, localized transport choices rather than detailed station or pickup instructions:

```text
id
airport_page_id
access_type
name
destination_label
summary
duration_min_minutes NULL
duration_max_minutes NULL
price_min NULL
price_max NULL
currency_code NULL
operating_hours_summary NULL
booking_url NULL
primary_source_url
last_verified_at
display_order
status
created_at
updated_at
```

Allowed access types are `rail`, `metro`, `bus`, `taxi`, `ride_hailing`, `transfer`, and `other`.
Duration and price pairs have consistency checks. Unknown values remain `NULL`.

### `public.airport_lounges`

Stores only information useful for route planning:

```text
id
airport_page_id
name
location_summary
location_type
access_summary
amenities TEXT[]
official_url NULL
primary_source_url
last_verified_at
display_order
status
created_at
updated_at
```

Allowed location types are `airside`, `landside`, and `unknown`. Amenities are limited to a small
allowlist: `wifi`, `food`, `drinks`, `showers`, `rest_area`, and `work_area`.

### `public.airport_parking_information`

Stores one localized overview per airport page:

```text
id
airport_page_id UNIQUE
summary
short_stay_available NULL
long_stay_available NULL
reservation_available NULL
shuttle_available NULL
official_url NULL
primary_source_url
last_verified_at
status
created_at
updated_at
```

Nullable booleans distinguish unknown from false. Detailed tariffs are out of scope.

### `public.airport_page_notices`

Stores a small ordered set of durable planning notices:

```text
id
airport_page_id
notice_type
title
body
severity
primary_source_url
last_verified_at
display_order
status
created_at
updated_at
```

Allowed notice types are `general`, `access`, `connection`, and `airport_confusion`. Allowed
severity values are `info` and `important`; the product does not represent real-time critical
alerts.

### `public.airport_page_faqs`

Follows the current city FAQ shape with `airport_page_id`, question, answer, answer type, ordering,
publication state, and review timestamps. A polymorphic FAQ table is intentionally not introduced.

## Refresh flow

Replace the city-only orchestration name with:

```text
public.refresh_pseo_read_models()
```

The function performs one transaction:

1. generate one `data_version`;
2. rebuild `pseo_direct_routes` using the current route/service/source eligibility rules;
3. rebuild `city_destination_summaries`;
4. refresh outbound and inbound `city_pages` facts;
5. refresh `airport_pages` inbound and outbound facts;
6. derive city and airport indexability;
7. synchronize `pseo_pages`;
8. update generated internal-link versions;
9. return deterministic row counts and the shared version.

The existing `public.refresh_city_pseo_read_models()` remains temporarily as a thin compatibility
wrapper around `refresh_pseo_read_models()` only if an existing caller requires it. If repository
search finds no caller outside tests and seeds, it is removed instead.

Route eligibility is written once in the rebuild step. City and airport fact refreshes only read
the eligible projection.

## Airport request functions

### Private identity helpers

`private.parse_airport_page_identity(JSONB)` validates:

- input is an object;
- `airport_iata` normalizes to uppercase and matches `^[A-Z]{3}$`;
- locale follows the existing locale contract.

`private.resolve_airport_page_context(TEXT, TEXT)` resolves:

- airport;
- airport page;
- pSEO page;
- city and country;
- current `data_version`.

Stable errors:

```text
ERR_INVALID_REQUEST
ERR_AIRPORT_NOT_FOUND
ERR_AIRPORT_PAGE_NOT_FOUND
```

### `public.rpc_get_airport_page(JSONB)`

Returns the page shell in the shared `{ data, meta, error }` envelope:

```text
airport identity and city/country
reviewed SEO content
quick facts
featured outbound routes
featured inbound routes
airline summaries
published access options
published parking information
published lounges
published notices
published FAQs
published internal-link groups
canonical, indexability, freshness, and version metadata
```

Featured route lists are bounded by validated request limits and use deterministic ranking:
known frequency descending, route count descending, shortest duration ascending, then stable entity
name ordering.

### `public.rpc_search_airport_direct_routes(JSONB)`

Required input:

```text
airport_iata
locale
direction: outbound | inbound
```

Optional filters:

```text
airlines
countries
max_duration_minutes
seasonality
limit
offset
```

The limit is bounded at 100. Outbound reads `origin_airport_id`; inbound reads
`destination_airport_id`. Results and airline/country facets derive from the same filtered CTE and
the airport page's resolved `data_version`.

Filter URLs canonicalize to the base airport page and are not registered in the sitemap.

## Internal links

Reuse `public.pseo_internal_links`. Add clusters:

```text
outbound_routes
inbound_routes
nearby_airports
city_flights_from
city_flights_to
airport_airlines
```

Links may target only registered published pages. Airport pages link to the outbound and inbound
city pages when those pages exist. City pages link to airports serving the city. Nearby airports
are derived from coordinates only when the target airport page is published; no stored nearby
airport table is added.

## Indexability

An airport page is indexable only when:

- airport status is `active`;
- airport has an IATA code;
- page status is `published`;
- reviewed content exists;
- at least one eligible inbound or outbound direct route exists;
- no route uses a development-only or SEO-disallowed source;
- route freshness is within the configured publication threshold;
- at least one published, verified access option exists.

Parking and lounge content improve page completeness but do not block indexability because some
airports legitimately lack verified data for them.

Stable noindex reasons:

```text
development_fixture
not_published
airport_inactive
missing_iata
no_direct_routes
content_not_reviewed
missing_access_information
source_not_seo_eligible
stale_route_data
```

City indexability continues to use the same source-rights checks and applies them to the page's
selected direction.

## Data ownership and update path

- Normalized airport, airline, route, and service records are updated through the existing
  ingestion/publish boundary.
- Reviewed airport content is stored only in airport pSEO tables.
- Development preview content remains under `supabase/seed` and is always noindex with
  `development_fixture`.
- SQL source remains authoritative. Generated migrations are never edited directly.
- The shared refresh is run after route publication or reviewed page-content publication.

No automated AI publishing, generic CMS, content history system, or provider-specific airport
operational schema is added.

## Verification

Test-first SQL contracts cover:

- outbound and inbound city page identity;
- the shared projection and one coherent `data_version`;
- airport page resolution by normalized IATA;
- outbound and inbound route results;
- airline, country, duration, and seasonality filters;
- facets derived from the same filtered relation;
- deterministic featured route ordering;
- access, parking, lounge, notice, and FAQ publication filtering;
- missing and invalid airport errors;
- page and source-rights indexability gates;
- development fixtures never becoming indexable;
- RLS and service-role-only execution;
- existing city pSEO RPC compatibility;
- route discovery remaining unchanged.

After SQL source changes, regenerate the clean migration foundation, rebuild local Supabase from
zero, run pSEO and route-discovery SQL contracts, run security/privilege checks, and run
`git diff --check`.

## Intentional exclusions

- Live departures, arrivals, fares, and availability.
- Terminal maps, gates, counters, and detailed airport services.
- Parking tariff history.
- Lounge reviews and availability.
- Stored nearby-airport relationships.
- Generic polymorphic content tables.
- A second airport-specific route projection.
- An inbound city summary table without measured performance need.
