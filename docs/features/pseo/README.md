# Interactive pSEO

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

## Data flow

```text
countries + cities + airports
airlines + flight_routes + flight_services
                    │
                    ▼
   refresh_city_pseo_read_models()
                    │
                    ├── city_direct_routes
                    ├── city_destination_summaries
                    └── city_pages facts/version
                    │
                    ▼
      rpc_get_city_page(jsonb)
      rpc_search_city_direct_routes(jsonb)
                    │
                    ▼
              Next.js city page
```

## Tables

- `city_direct_routes` keeps scalar airport, airline, country, duration, and departure dimensions at
  filterable route grain.
- `city_destination_summaries` provides stable default city-to-city destination cards.
- `pseo_pages` registers canonical paths, publication state, and indexability.
- `city_pages` stores reviewed metadata, content, quick facts, freshness, and data version.
- `city_page_faqs` stores ordered reviewed FAQ content.
- `pseo_internal_links` stores semantic internal-link edges and placement decisions.

All tables enable RLS, revoke access from `anon` and `authenticated`, and are available only through
the service-role server boundary.

## Get a city page

```sql
SELECT public.rpc_get_city_page(
  '{
    "city_slug": "bangkok",
    "locale": "en-GB",
    "destination_limit": 8
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
SELECT public.rpc_search_city_direct_routes(
  '{
    "city_slug": "bangkok",
    "origin_airports": ["DMK"],
    "airlines": ["FD"],
    "destination_countries": ["VN", "SG"],
    "max_duration_minutes": 240,
    "departure_window": "morning",
    "limit": 20,
    "offset": 0
  }'::JSONB
);
```

Supported filters:

- `origin_airports`
- `airlines`
- `destination_countries`
- `max_duration_minutes`
- `departure_window`
- `limit`
- `offset`

Results and airport, airline, and country facets derive from the same filtered relation.

## Next.js consumption

The Next.js server calls the RPCs with a server-only service-role key:

```text
POST /rest/v1/rpc/rpc_get_city_page
POST /rest/v1/rpc/rpc_search_city_direct_routes
```

The browser must never receive the service-role key. The page shell should render from
`rpc_get_city_page`; URL-backed filters should call `rpc_search_city_direct_routes`.

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
  -f supabase/snippets/e2e_city_pseo.sql

psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 \
  -f supabase/snippets/e2e_route_discovery.sql
```

## Deferred scope

- Production source ingestion and publish workflow.
- Public Next.js route handlers and CDN cache headers.
- City-to-city route page payloads.
- Airport, airline-city, country-route, and guide page payloads.
- Sitemap endpoint.
- Localized editorial workflow beyond the seeded `en-GB` preview.
- Live dated schedules, availability, prices, offers, and booking.
- Indexable filter combinations.
- Automated AI content publishing.
