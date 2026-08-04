# Route Discovery

## Responsibility

Route Discovery builds structurally possible journeys of zero to three stops from recurring
schedules. It does not claim dated inventory, seats, live fares, fare rules, or booking
availability.

## Shared read path

```text
flight_routes + flight_services
              │
              ▼
      refresh_route_options()
              │
              ▼
         route_options
              │ publication build
              ▼
 refresh_route_search_options(version)
              │
              ▼
     route_search_options
              │
              ▼
 rpc_search_route_options_v2(jsonb)
              │
              ▼
       route-search-query
```

Homepage, City, Airport, and Route pages use this one search projection and contract. Supported
scopes are `global`, `origin_city`, `origin_airport`, and `city_pair`. Shared filters include stops,
airlines, connection airports, total duration, maximum per-leg layover, cabin, price/currency, and
keyset pagination.

The Edge transport validates and normalizes the request once. PostgreSQL revalidates the contract,
owns filtering/facets/ranking, and returns the shared `{ data, meta, error }` envelope. Ranking is
deterministic: fewer stops, shorter duration, higher confidence, then UUID.

## Provider boundary

Base-data and price providers map into canonical ingestion contracts. Changing provider adapters
does not change page or route-search contracts. Missing, expired, or unlicensed prices remain
explicit null states and never become zero or live availability.

## Verification

```bash
supabase db reset --local --yes
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 -f supabase/snippets/e2e_shared_route_search.sql
deno test --config supabase/functions/deno.json --allow-read supabase/functions
```

Development fixtures prove valid direct, one-, two-, and three-stop paths. Their source rights keep
them permanently non-production and non-indexable.
