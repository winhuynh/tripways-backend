# Singapore City pSEO Fixture Design

## Goal

Provide a complete development-only Singapore city fixture that renders through
the same pSEO read models and Next.js route as Bangkok.

## Scope

- Add one complete `public.city_pages` record for Singapore.
- Add Changi airport presentation content.
- Add a small recurring direct-route graph originating at Singapore.
- Add city insights, FAQ, and internal-link content required by the existing
  read models.
- Keep every new record non-indexable and tied to the existing development-only
  data source.

## Architecture

All records remain in `supabase/seed`; migrations, schemas, RPCs, Edge Functions,
and frontend code remain unchanged. Existing generic city-page RPCs must resolve
Singapore by `city_slug = 'singapore'`.

## Acceptance criteria

- `rpc_get_city_overview` returns Singapore.
- Airport, destination, airline, quick-facts, route-map, insights, FAQ, and
  internal-link read models return non-empty valid envelopes.
- `/flights-from/singapore` renders without a city setup/not-found error.
- Bangkok fixture behavior remains unchanged.
