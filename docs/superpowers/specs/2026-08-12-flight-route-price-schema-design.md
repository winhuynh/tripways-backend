# Flight Route Price Schema Design

## Decision

Tripways does not maintain a canonical flight-route database. Route-page identity belongs to
`public.route_pages`, route discovery belongs to the replaceable read model
`public.flight_route_options`, and short-lived Travelpayouts prices belong to
`public.flight_route_prices`.

Remove `public.flight_routes`. Rename `public.flight_content_observations` and its source file to
`public.flight_route_prices`. Do not create compatibility tables or views because migrations are
still regenerated as a clean foundation.

## `public.flight_route_prices`

The renamed table keeps the current normalized cached-fare fields, references, TTL constraints,
RLS, and service-role-only grants. Rename its constraints and indexes consistently.

Add `data_source TEXT NOT NULL`. For the current adapter every inserted row uses
`data_source = 'travelpayouts'`. Constrain the value to the provider identifier format used by
Tripways. Keep `source_id REFERENCES admin.data_sources(id)` as the authoritative rights and
retention relationship; `data_source` is the explicit, readable provider label requested for each
row.

No raw Travelpayouts response is retained. A refresh atomically deletes the provider's current
rows and inserts the newly normalized price set. `valid_until` remains bounded to seven days.

## Data flow

1. The Travelpayouts adapter fetches cached fares and normalizes them.
2. `admin.publish_price_estimate_batch` writes receipt metadata to
   `admin.raw_import_batches`.
3. It replaces Travelpayouts rows in `public.flight_route_prices`, setting
   `data_source = 'travelpayouts'`.
4. Route-page payloads and affiliate handoff read the renamed table.
5. `admin.refresh_route_search_options` derives route availability from fresh price rows only;
   it no longer reads `public.flight_routes`.
6. The frontend contract remains unchanged: it receives observed price metadata and never receives
   `affiliate_path` directly.

## Removal and updates

- Delete the `flight_routes.sql` source and remove it from migration generation.
- Rename `flight_content_observations.sql` to `flight_route_prices.sql`.
- Update ingestion, cron, pSEO builders, price resolution, affiliate handoff, route discovery,
  SQL snippets, contract expectations, and technical documentation.
- Regenerate migrations from `supabase/sql_src` and reset Supabase local.

## Verification

- A rebuilt database contains `public.flight_route_prices` and does not contain
  `public.flight_routes` or `public.flight_content_observations`.
- Fresh Travelpayouts rows have `data_source = 'travelpayouts'` and a maximum seven-day lifetime.
- `anon` and `authenticated` cannot select the table directly.
- Route page price output and affiliate handoff continue using an opaque observation ID.
- Relevant SQL contracts, ingestion tests, Deno checks, migration reset, and `git diff --check`
  pass.

## Explicit exclusions

- No live fare inventory, schedules, or historical price warehouse.
- No compatibility view for the removed table names.
- No frontend redesign or provider-specific table.
