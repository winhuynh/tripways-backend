# Route Discovery

Route Discovery materializes one disposable projection for search and all pSEO page builders:

```text
       current flight_route_prices
                    │
                    ▼
          flight_route_options(publication_version)
                    │
                    ▼
              rpc_search_routes(jsonb)
```

The projection contains direct directional evidence, canonical geography, optional airline
identity, and at most one fresh observed amount. It contains no schedule, recurrence, connection,
layover, live availability, or synthetic price range.

Provider adapters publish the same observation contract, so changing provider does not change page
or search consumers. A daily cron checks freshness and refreshes Travelpayouts on day six, or sooner
when the provider expiry has already passed.
