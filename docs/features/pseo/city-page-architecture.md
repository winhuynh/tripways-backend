# City Page Architecture

## Page identity

The canonical City Hub identity is a city slug such as `/flights-from/bangkok`. Airports are
filter dimensions, not separate city-page identities.

## Initial page load

`public.city_page_read_models` stores one bounded payload for each publication version, city, and
locale. `public.rpc_get_page_v2(jsonb)` joins that table to the one current publication version and
returns the complete shell in one indexed `SELECT`. Request-time code does not rebuild page
modules.

The payload contains city/country identity, airports, reviewed SEO content, quick facts, cited
facts, an initial route result, explicit price state, airlines, FAQs, semantic internal links,
canonical metadata, freshness, and indexability.

## Interactive route search

City filters use `public.rpc_search_route_options_v2(jsonb)` with an `origin_city` scope. The same
contract powers Homepage, Airport, Route Page, and generic route discovery:

```json
{
  "scope": { "type": "origin_city", "key": "bangkok" },
  "filters": {
    "max_stops": 3,
    "airlines": ["TG"],
    "connection_airports": ["SIN"],
    "max_duration_minutes": 1200,
    "max_layover_minutes": 300,
    "cabin": "economy",
    "price_max": 900,
    "currency": "USD"
  },
  "page_size": 20,
  "after": null
}
```

PostgreSQL owns route eligibility, scope, filters, facets, keyset pagination, ranking, source
rights, and price visibility. The Edge layer only parses, maps the canonical transport once, calls
the RPC, and validates the shared envelope.

## Publication and safety

`public.publish_read_model_version(text)` builds the shared route projection and all four page
models under one candidate version. It validates the candidate before atomically changing the
current marker. A transaction-scoped advisory lock serializes publishers; failed candidates remain
recorded while the prior version stays current.

Every exposed table has RLS enabled. Only `service_role` can read the page/search projections or
execute their RPCs. Development fixtures remain `noindex` and cannot become production content.
