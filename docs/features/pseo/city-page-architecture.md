# City Page Architecture

## Page identity

The canonical City Hub identity is a city slug such as `/flights-from/bangkok`. Airports are
filter dimensions, not separate city-page identities.

## Initial page load

`public.city_page_read_models` stores one bounded payload for each publication version, city, and
locale. `public.rpc_get_page(jsonb)` joins that table to the current publication version and returns
the complete page envelope in one indexed read. Request-time code does not rebuild page modules.

The payload contains public city/country identity, airports, reviewed content, quick facts, cited
facts, fresh route options, optional estimated prices, FAQs, canonical metadata, freshness, and
indexability. Internal database identifiers are not part of the public DTO.

## Interactive route search

City filters use `public.rpc_search_routes(jsonb)` with an `origin_city` scope:

```json
{
  "scope": { "type": "origin_city", "key": "bangkok" },
  "filters": { "currency": "USD", "max_amount": 900 },
  "page_size": 20
}
```

PostgreSQL owns route eligibility, bounded filters, ranking, source rights, and price freshness.
The Edge layer validates transport input, calls the RPC with `service_role`, and returns the shared
envelope.

## Publication and safety

`public.publish_read_model_version(text)` builds the shared route projection and the city, airport,
and route page models under one candidate version before atomically changing the current marker.
A transaction-scoped advisory lock serializes publishers; a failed candidate leaves the previous
version current.

Every exposed table has RLS enabled. Only `service_role` can read page/search projections or invoke
their RPCs. Development fixtures and staging publications remain `noindex`.
