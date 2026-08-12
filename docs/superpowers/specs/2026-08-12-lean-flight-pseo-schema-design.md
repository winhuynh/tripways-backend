# Lean Flight and pSEO Schema Design

**Status:** Approved  
**Date:** 2026-08-12

## Goal

Reduce the Tripways application schema from roughly forty-five narrowly scoped tables to a small,
explicit set of canonical reference, flight discovery, page source, and immutable read-model tables.
The schema must reflect the current product: pSEO content plus short-lived Travelpayouts observations,
not a schedule database.

## Principles

- Keep canonical entities relational when they are shared by multiple consumers.
- Keep page-owned editorial modules in one validated JSONB aggregate per page and locale.
- Keep immutable read models separate from editable page source.
- Do not persist concepts without a current provider or product use case.
- Never convert cached fare observations into schedule facts.
- Preserve provider identifiers even when canonical resolution is incomplete.
- Keep public access behind service-role RPCs; source and read-model tables retain RLS and closed grants.

## Canonical reference

Retain `countries`, `cities`, `airports`, `airlines`, and `place_aliases`.

`cities` gains nullable `iata_code`, `currency_code`, and `primary_language`; its existing timezone
remains canonical. City/metro codes such as LON, NYC, and TYO live in `cities.iata_code`, while
`airports.city_id` is the only city-airport relationship.

Remove `metro_areas`, `metro_area_airports`, `nearby_airports`, `airport_terminals`, and
`airport_terminal_airlines`. These concepts may return only with a concrete provider and consumer.

## Flight domain

### `flight_routes`

Represent only directional airport-pair evidence. Retain origin, destination, source lineage,
status, and freshness. Store nullable canonical airline ID alongside nullable provider airline IATA.
Remove schedule frequency, weekdays, seasonality, codeshare, marketing-airline, and confidence fields.

### `flight_content_observations`

Replace the legacy `route_price_estimates` table. Store one short-lived normalized provider
observation with `provider_airline_iata`, nullable `canonical_airline_id`, `observed_amount`, currency,
trip/direct/transfer facts, dates, duration, market/locale, observed time, expiry, affiliate path, and
source/batch lineage. A publication replaces the source's prior current set. Validity is at most 24h.

### `flight_route_options`

Replace `route_search_options` with a versioned direct-route projection. It contains geography,
airport pair, optional airline, optional current observed amount/currency/expiry, canonical page path,
and publication version. It contains no schedule times, weekdays, connections, layovers, or price
range. `flight_services` is removed and no connecting itinerary is synthesized.

## Page source aggregates

Retain exactly three editable page source tables: `city_pages`, `airport_pages`, and `route_pages`.
Each retains identity, locale, SEO/editorial lifecycle, review metadata, and gains a validated
`content JSONB` object.

- `city_pages.content`: `facts`, `sections`, `airports`, `faqs` arrays.
- `airport_pages.content`: `journey_steps`, `access_options`, `facilities`, `lounges`, `parking`,
  `notices`, `faqs`.
- `route_pages.content`: `airport_comparisons`, `travel_facts`, `editorial_sections`, `faqs`.

Remove all page-owned child content tables after migrating seed/fixture content into these aggregates.
Stable city facts (`currency_code`, `primary_language`, `timezone`) live on `cities`; localized facts,
citations, and editorial copy live in `city_pages.content`.

## Publication

Retain `pseo_pages`, `publication_versions`, `pseo_internal_links`, and the three immutable read-model
tables. Publication validates aggregate shapes, builds one payload per page/version, refreshes
`flight_route_options`, and atomically marks a version current. Request RPCs read only the current
read models and route projection.

## Removed tables

Remove: `metro_areas`, `metro_area_airports`, `nearby_airports`, `airport_terminals`,
`airport_terminal_airlines`, `flight_services`, `city_facts`, `city_content_sections`,
`city_page_airport_content`, `city_page_faqs`, `airport_journey_steps`, `airport_access_options`,
`airport_facilities`, `airport_lounges`, `airport_parking_information`, `airport_page_notices`,
`airport_page_faqs`, `route_page_airport_comparisons`, `route_page_travel_facts`,
`route_page_editorial_sections`, and `route_page_faqs`.

## Compatibility and migration

This repository regenerates its baseline migrations from `supabase/sql_src`; local fixtures are
rewritten to the new schema rather than maintaining compatibility views. Public RPC names remain
versionless, but their internal SQL and response fields use `observed_amount`. The legacy physical
table and projection names disappear.

## Verification

- SQL contract tests prove removed tables are absent and retained tables have RLS/closed grants.
- Observation tests prove provider airline IATA survives unresolved canonical mapping.
- Page contract tests prove each source page owns one aggregate and read models remain separate.
- Migration regeneration and local reset must succeed from an empty database.
- Ingestion, pSEO, route-search, and focused SQL E2E tests must pass.
