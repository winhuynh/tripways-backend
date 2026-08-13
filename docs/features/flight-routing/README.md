# Flight Routing

## Current boundary

Flight Routing stores a compact provider-neutral reference graph plus replaceable route evidence.
It does not store schedules, inventory, historical fares, or a provider response archive.

Dependency order:

1. `admin.data_sources`
2. `countries`, `cities`, `airports`, `airlines`
3. `flight_route_prices`

`cities.iata_code` owns metro identity; stable city facts live on `cities`.
`flight_route_prices` preserves provider airline IATA even when no canonical airline resolves and
stores normalized estimated prices for at most seven days. An on-demand publication replaces only
its canonical origin/market/currency/locale cache scope; it never deletes another origin.

All tables deny direct client access and are available only through reviewed RPC/Edge boundaries.
A licensed schedule provider can add a separate schedule model later without changing these facts.
