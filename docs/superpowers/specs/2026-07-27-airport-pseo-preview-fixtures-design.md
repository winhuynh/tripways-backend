# Airport pSEO Preview Fixtures Design

## Goal

Provide deterministic development-only airport pSEO content for BKK, DMK, and SIN so the web
application can exercise distinct airport-page states against the real local RPC contracts.

## Boundary

- Reuse normalized airports, airlines, routes, and services already present in the flight-routing
  and city pSEO fixtures.
- Add only missing route/service records required to give each airport useful inbound and outbound
  coverage.
- Store airport-page metadata and reviewed guidance in the airport pSEO tables.
- Never seed derived route counts, facets, rankings, freshness, or data versions.
- Every preview page remains `is_indexable = false` with `development_fixture`.

## Fixture profiles

### BKK

- Full-service international hub profile.
- Rail access, parking overview, one lounge, and a notice distinguishing BKK from DMK.
- Both inbound and outbound route coverage.

### DMK

- Low-cost and regional route profile.
- Bus/taxi access, parking overview, one lounge, and a notice distinguishing DMK from BKK.
- Both inbound and outbound route coverage.

### SIN

- Single-airport international hub profile.
- Metro/taxi access, parking overview, two lounge examples, and a durable connection-planning
  notice.
- Both inbound and outbound route coverage.

## Seed ownership

`supabase/seed/airport_pseo_fixture.sql` owns all three airport page records and their access,
parking, lounge, notice, and FAQ rows. Route records remain in the existing flight-routing/city pSEO
fixture that owns the normalized graph.

## Verification

The airport pSEO SQL contract refreshes the shared projection and verifies:

- all three airport pages resolve;
- every page has at least one inbound and outbound route;
- reviewed child content is returned in display order;
- BKK, DMK, and SIN share the refresh `data_version`;
- development sources keep every preview page noindex;
- anonymous and authenticated roles cannot read tables or execute airport RPCs.

## Exclusions

- Production content and source URLs.
- Live fares, schedules, availability, gates, terminals, maps, or operational alerts.
- Detailed parking tariffs or lounge reviews.
