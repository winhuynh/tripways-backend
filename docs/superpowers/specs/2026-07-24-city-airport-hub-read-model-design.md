# City Airport Hub Read Model Design

## Goal

Return complete, version-consistent airport hub cards for a city pSEO page without storing derived
route statistics or locale-specific copy in the normalized `airports` table.

## Boundaries

- `public.airports` remains the normalized source for airport identity, geography, type, status, and
  lineage.
- `public.airlines.business_model` classifies an airline as `full_service`, `low_cost`, `regional`,
  `charter`, `cargo`, `hybrid`, or `unknown`.
- `public.city_page_airport_content` stores reviewed, locale-specific hub labels, descriptions,
  ordering, and publication state for one airport within one city page.
- `public.city_direct_routes` remains the versioned source for airport route statistics.
- `private.get_city_airport_route_stats()` derives reusable statistics for every active airport in
  one city and one data version.
- `public.rpc_get_city_airports()` composes normalized airport facts, reviewed content, and derived
  statistics into one bounded read model.

## Derived statistics

Counts use distinct destination cities and distinct operating airlines. Domestic and international
percentages use distinct destination cities as the denominator so the labels describe destination
coverage rather than service frequency. The dominant airline business model is weighted by
`frequency_per_week` when known and falls back to distinct route count when frequency is unknown.
An airport with no routes returns zero counts, zero percentages, and `unknown`.

## RPC contract

Each airport item returns identity fields, `is_primary`, optional `hub_label` and `description`,
`display_order`, direct/domestic/international destination counts and percentages, `airline_count`,
`dominant_airline_business_model`, and `page_path`. The envelope metadata continues to expose the
resolved `data_version`.

Only content rows with `status = 'published'` are returned. Airports without published content
remain visible with nullable editorial fields after the numeric airport ordering.

## Seed and migration policy

Bangkok BKK and DMK editorial content and airline classifications live only in `supabase/seed`.
Statistics are never seeded or hardcoded. All schema and function changes are made under
`supabase/sql_src`, then the existing deterministic generator rebuilds the clean migration
foundation.

## Verification

Rollback-based SQL contracts verify BKK/DMK content, exact derived counts, domestic/international
percentages, business-model classification, ordering, envelope shape, missing-city errors, and
least-privilege execution. A full local database reset proves migrations and seeds rebuild from
zero.
