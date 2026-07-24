# Route Discovery

## Responsibility

Route Discovery finds structurally possible direct and one-stop journeys from the stored schedule
graph. It does not search dated inventory, seat availability, or fares. Those belong to the future
Live Flight Search feature and its external provider adapter.

## Data flow

```text
flight_routes + flight_services
              │
              ▼
  refresh_route_options()
              │
              ▼
        route_options
              │
              ▼
   rpc_search_routes(jsonb)
              │
              ▼
route-discovery-query Edge Function
```

- `flight_routes` stores directional network topology, trust status, and source lineage.
- `flight_services` stores recurring schedule patterns, validity ranges, local times, and duration.
- `route_options` stores a rebuildable direct/one-stop read model optimized for filtering.
- PostgreSQL owns schedule compatibility, filtering, facets, pagination, and stable ranking.
- Edge code validates transport shape, calls the RPC, normalizes errors, and emits safe logs.

## Supported request

`POST /functions/v1/route-discovery-query`

```json
{
  "action": "search_routes",
  "input": {
    "from": "SGN",
    "to": "LHR",
    "max_stops": 1,
    "airlines": ["SQ"],
    "exclude_airports": ["BKK"],
    "max_duration_minutes": 1200,
    "max_layover_minutes": 240,
    "departure_window": "morning",
    "limit": 20,
    "offset": 0
  }
}
```

The public result uses `{ status, data, error }`. Successful `data` contains `routes`,
`pagination`, and `facets`. Ranking remains database-owned and deterministic: fewer stops, shorter
total duration, higher confidence, then UUID.

Stable Route Discovery errors are `ERR_ROUTE_DISCOVERY_INVALID_REQUEST`,
`ERR_ROUTE_DISCOVERY_UNAVAILABLE`, and `ERR_ROUTE_DISCOVERY_CONTRACT`. Internal SQL and provider
errors are never returned to callers.

## Local fixture

The deterministic fixture contains SGN, SIN, BKK, LHR, and CDG. It proves:

- two direct SGN to LHR schedule options;
- one valid SGN to SIN to LHR option with a 135-minute connection;
- rejection of a 20-minute BKK connection;
- rejection of a service attached to an inactive route.

Its source is development-only with production, SEO, and derived-data rights disabled. It must
never be reused as publishable content.

## Verification

```bash
supabase db reset --local --yes
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 -f supabase/snippets/e2e_route_discovery.sql
deno test --config supabase/functions/deno.json --allow-env --allow-read \
  supabase/functions/v1/route-discovery/query/tests
```

## Deferred scope

- Licensed base-data and schedule ingestion
- Multi-stop search beyond one connection
- Minimum connection time by airport, terminal, and itinerary type
- Real dated offers, fare rules, booking links, and affiliate redirects
- Public rate limiting and production cache policy
- pSEO route-page read models and publication gates
