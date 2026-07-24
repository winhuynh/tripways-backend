# Flight Routing

## Current boundary

This foundation owns the normalized reference graph used by Route Discovery. It stores geography,
airports, airlines, directional route edges, source rights, and recurring flight services. Search
behavior and its derived read model belong to the separate `route-discovery` feature.

## Table dependency order

1. `admin.data_sources`
2. `public.countries`
3. `public.cities`
4. `public.airports`
5. `public.airlines`
6. `public.flight_routes`
7. `public.flight_services`

The tables live in PostgreSQL schemas based on data exposure and responsibility. They remain part
of one product feature: `flight-routing`.

## SQL source ownership

- `supabase/sql_src/schema/flight_routing/data_sources.sql`
- `supabase/sql_src/schema/flight_routing/countries.sql`
- `supabase/sql_src/schema/flight_routing/cities.sql`
- `supabase/sql_src/schema/flight_routing/airports.sql`
- `supabase/sql_src/schema/flight_routing/airlines.sql`
- `supabase/sql_src/schema/flight_routing/flight_routes.sql`

Each file defines exactly one table, its table-owned indexes, constraints, RLS state, and grants.
`flight_routes` answers whether an eligible directional relationship exists. `flight_services`
answers when a recurring flight operates. Neither table stores dated live availability or fares.

## Access model

All exposed domain tables have RLS enabled. `anon` and `authenticated` currently have no
table privileges or policies. Only `service_role` can read or mutate the data until a reviewed API
or RPC boundary exists.

## Deferred work

- OurAirports importer
- Licensed schedule-provider adapter
- Dated live schedules, seat availability, and prices
