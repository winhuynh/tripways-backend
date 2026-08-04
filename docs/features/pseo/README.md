# Interactive pSEO

## Source organization

Schema and function sources use the same page-owned layout:

```text
supabase/sql_src/{schema,functions}/pseo/
├── shared/
├── homepage/
├── city/
├── airport/
└── route/
```

`shared` contains only cross-page publication, dispatch, sitemap, internal-link, and price
contracts. Each page folder contains its own content, read model, and builder sources. Generated
migrations remain ordered explicitly by `scripts/regenerate-supabase-migrations.sh`.

## Responsibility

Interactive pSEO turns approved route data into bounded, frontend-ready landing-page payloads.
The first implemented page type is a city-origin page:

```text
/flights-from/bangkok
```

The page identity is the city. Airports such as BKK and DMK are filter dimensions inside the
Bangkok page.

Interactive pSEO does not own normalized routes, recurring schedules, live availability, or fares.
It consumes the published Flight Routing source tables and produces rebuildable read models.

The same route projection also powers airport pages:

```text
/airports/suvarnabhumi-bkk
```

Airport pages prioritize direct routes and airlines, then add a small reviewed content layer for
ground access, parking, lounges, notices, and FAQs. They do not replace official airport operations
or provide live departures, terminal maps, gates, counters, shops, or security wait times.

## Data flow

```text
countries + cities + airports
airlines + flight_routes + flight_services
                    │
                    ▼
       refresh_pseo_read_models()
                    │
                    ├── pseo_direct_routes
                    ├── city_destination_summaries
                    ├── city_pages facts/version
                    └── airport_pages facts/version
                    │
                    ▼
      four page-specific read-model tables
      rpc_get_page_v2(jsonb)
      rpc_search_route_options_v2(jsonb)
                    │
                    ▼
              Next.js city page
```

## Tables

- `pseo_direct_routes` keeps scalar city, airport, airline, country, duration, and departure
  dimensions at filterable route grain for both city and airport pages.
- `city_destination_summaries` provides stable default city-to-city destination cards.
- `pseo_pages` registers canonical paths, publication state, and indexability.
- `city_pages` stores reviewed metadata, content, quick facts, freshness, and data version.
- `city_page_faqs` stores ordered reviewed FAQ content.
- `pseo_internal_links` stores semantic internal-link edges and placement decisions.
- `airport_pages` stores reviewed airport metadata, content, route facts, freshness, and version.
- `airport_access_options`, `airport_lounges`, `airport_parking_information`,
  `airport_page_notices`, and `airport_page_faqs` store focused reviewed airport guidance.

## Get an airport page

```sql
SELECT public.rpc_get_airport_page(
  '{
    "airport_iata": "BKK",
    "locale": "en-GB",
    "route_limit": 8
  }'::JSONB
);
```

The payload includes airport/city/country identity, reviewed SEO content, route facts, featured
outbound and inbound routes, airline summaries, published airport guidance, semantic links,
canonical metadata, indexability, freshness, and the shared data version.

## Filter airport routes

```sql
SELECT public.rpc_search_route_options_v2(
  '{
    "scope": {"type": "origin_airport", "key": "BKK"},
    "filters": {
      "max_stops": 3,
      "airlines": ["TG"],
      "max_duration_minutes": 360
    },
    "page_size": 20
  }'::JSONB
);
```

Results and facets derive from the same shared filtered relation. Filtered URLs canonicalize to the
base airport page and are not sitemap entries.

All tables enable RLS, revoke access from `anon` and `authenticated`, and are available only through
the service-role server boundary.

## Get a city page

```sql
SELECT public.rpc_get_page_v2(
  '{
    "page_type": "city",
    "entity_key": "bangkok",
    "locale": "en-GB"
  }'::JSONB
);
```

The payload uses `{ data, meta, error }` and includes:

- City and country identity.
- SEO metadata and reviewed content.
- All active airports in the city.
- Version-consistent quick facts.
- Featured direct destinations.
- Airline and country summaries.
- FAQs.
- Semantic internal-link groups.
- Canonical, indexability, freshness, and data-version metadata.

## Filter direct destinations

```sql
SELECT public.rpc_search_route_options_v2(
  '{
    "scope": {"type": "origin_city", "key": "bangkok"},
    "filters": {
      "max_stops": 3,
      "airlines": ["FD"],
      "max_duration_minutes": 240
    },
    "page_size": 20
  }'::JSONB
);
```

The same stops, airline, connection-airport, duration, layover, cabin, price, currency, and cursor
semantics apply to every page scope.

## Next.js consumption

The Next.js server calls the RPCs with a server-only service-role key:

```text
POST /functions/v1/page-query
POST /functions/v1/route-search-query
```

The browser must never receive the service-role key. Every page shell renders from exactly one
page-specific current read-model row through `page-query`; interactive filters call
`route-search-query`.

Filter URLs canonicalize to the base city page and are not sitemap entries:

```text
/flights-from/bangkok?airport=BKK
→ canonical /flights-from/bangkok
```

## Local preview fixture

`supabase/seed/city_pseo_fixture.sql` adds:

- BKK and DMK under Bangkok.
- Thai Airways and Thai AirAsia route examples.
- Direct destinations for London, Paris, Singapore, and Ho Chi Minh City.
- Editable placeholder metadata and content.
- Four FAQs.
- Popular-route and change-source-city internal-link groups.

Every preview page has:

```text
is_indexable = false
noindex_reason = development_fixture
```

The fixture must never be reused as production or indexable data.

## Verification

```bash
supabase db reset --local --yes

psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 \
  -f supabase/snippets/e2e_provider_ready_pages.sql

psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 \
  -f supabase/snippets/e2e_shared_route_search.sql
```

## Provider-ready page foundation

Homepage discovery, City Hub, Airport Hub and city-pair Route Page now have stable database RPCs
and thin Edge transports. Structured facts always carry a citation and verification timestamp.
Price ranges are kept separate from live offers and return `missing`, `expired`, or `unlicensed`
instead of silently becoming zero. Sitemap eligibility is owned by Postgres; development fixtures
remain `noindex` through refreshes.

To change a price-data provider, register a new adapter under
`supabase/functions/v1/ingestion/price-estimates`, configure its provider key and credentials, and
map its response to `route-price-estimates.v1`. No page RPC, canonical table, or frontend contract
changes. Source rows in `admin.data_sources` must explicitly grant storage, derived-data and display
rights before publication succeeds.

## Deferred scope

- Production provider credentials and scheduled operations.
- Public Next.js route handlers and CDN cache headers.
- Localized editorial workflow beyond the seeded `en-GB` preview.
- Live dated availability, offers, booking and affiliate redirects.
- Indexable filter combinations.
- Automated AI content publishing.
