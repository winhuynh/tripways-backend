# Interactive pSEO

pSEO is a content/search presentation layer, not a flight database. Canonical identity and stable
geography live in the reference tables. Each page type owns one localized aggregate source row:

- `city_pages.content`
- `airport_pages.content`
- `route_pages.content`

`pseo_pages` alone owns canonical URL, publication status, indexability, and data version. Separate
city, airport, and route read-model tables are disposable publication snapshots for fast page reads.

```text
canonical references + aggregate page content + flight_route_options
                              │
                              ▼
              versioned city/airport/route read models
                              │
                              ▼
                         rpc_get_page
```

Dynamic route observations remain outside editorial JSON and are included only while fresh and
licensed for display. Search results hand users to the approved affiliate partner; Tripways never
claims cached observations are live inventory or final bookable prices.
