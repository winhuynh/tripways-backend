# Flight Routing

## Current boundary

Flight Routing stores a compact provider-neutral reference graph plus replaceable route evidence.
It does not store schedules, inventory, historical fares, or a provider response archive.

Dependency order:

1. `admin.data_sources`
2. `countries`, `cities`, `airports`, `airlines`, `place_aliases`
3. `flight_routes`
4. `flight_content_observations`

`cities.iata_code` owns metro identity; stable city facts live on `cities`. `flight_routes` only
asserts a directional relationship and preserves provider airline IATA even when no canonical
airline resolves. `flight_content_observations` stores the current normalized display snapshot for
at most seven days and is replaced by the next provider publication.

All tables deny direct client access and are available only through reviewed RPC/Edge boundaries.
A licensed schedule provider can add a separate schedule model later without changing these facts.
