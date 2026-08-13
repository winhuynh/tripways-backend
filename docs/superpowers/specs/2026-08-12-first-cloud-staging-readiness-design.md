# First Cloud Staging Readiness Design

## Goal

Prepare the Tripways backend for its first cloud staging deployment using real OurAirports and
Travelpayouts data while making database-enforced search-engine indexing impossible in staging.
Remove unused runtime objects and keep one explicit ingestion-to-publication path.

## Environment lifecycle

`public.publication_versions.source_type` supports `development_fixture`, `staging`, and
`production`. Staging publications always set every pSEO registry row to
`is_indexable = FALSE` and `noindex_reason = 'staging_environment'`. Only a production publication
may pass the reviewed-content, source-rights, and route-availability indexability gates.

The deployment environment is server configuration. Provider request bodies cannot choose whether
a publication is staging or production.

## Ingestion and publication

Base-data ingestion publishes canonical countries, cities, airports, airlines, and aliases without
requiring route prices or a complete pSEO publication. This permits the first OurAirports import
into an empty staging database.

Price ingestion resolves the incoming batch before deleting current provider prices. A batch with
zero usable prices fails closed and preserves the previous cache. A valid batch atomically replaces
the provider prices, synchronizes staging pSEO source pages, builds route and page read models, and
publishes one current staging version. The response includes the new data version.

Receipt metadata is retained only for the source's configured retention period. Cascading deletion
removes associated raw base-data records. Raw Travelpayouts responses and price history are never
stored.

## pSEO source synchronization

Replace the local-only page generator with
`admin.sync_provider_pseo_pages(p_environment TEXT)`. It upserts:

- city pages for cities with active airports;
- airport pages for active airports;
- directional route pages for fresh published route prices.

Generated content is a bounded factual identity and SEO shell. It does not invent schedules,
frequency, availability, or live prices. Generated pages have no review timestamp. Local and staging
pages remain noindex; production indexing still requires explicit review.

## Cron and staging bootstrap

Replace the two cron installers with `admin.configure_ingestion_crons()`. It validates required
Vault secrets, replaces jobs idempotently, schedules OurAirports daily, and checks Travelpayouts
daily while fetching only when no observation is newer than six days.

A staging-readiness verification script checks required Vault secret names, both active cron jobs,
the current staging publication, noindex enforcement, table/RPC privileges, and the absence of a
current fixture publication.

## Edge boundary

Keep the configured runtime endpoints for system health, user profile/security/deletion, page
query, route search, homepage statistics, sitemap, both ingestion paths, and affiliate handoff.
Every deployed entrypoint is included in type checking.

Remove the unused homepage-origin Edge/RPC, place-search RPC, and legacy route-price resolver.
Affiliate handoff remains public at the Edge boundary but its database RPC is executable only by
`service_role`. The Edge validates the opaque price ID, applies a bounded abuse limit, and returns
only an allowlisted Aviasales URL.

## Schema and function cleanup

Remove the empty `analytics` schema and unused city/airport identity helper functions. Keep page
payload builders because publication uses them. Keep the provider contract version
`flight-content-observations.v1` to avoid a no-value adapter protocol change, while database object
names and comments use route-price terminology.

No compatibility functions, schemas, or views are created because Tripways has no deployed
migration history yet.

## Security

- `admin` is not exposed by the Data API.
- Every Tripways table in `public` keeps RLS enabled.
- Domain writes and internal RPCs remain service-role-only.
- Staging uses separate secrets and keys from production.
- Ingestion requires the worker secret and server-selected environment.
- Public clients never receive provider tokens, service-role keys, raw provider payloads, or direct
  database access to affiliate paths.

## Verification

Regenerate migrations and reset Supabase local from zero. Verify base import without prices, cache
preservation on a zero-accepted price batch, atomic valid price publication, route/page read-model
refresh, empty staging sitemap, Edge-only affiliate resolution, two configured cron jobs, RLS and
grants, Deno format/type checks/tests, SQL contracts/E2E snippets, secret scans, and repository diff
formatting.

## Exclusions

- No production deployment or remote mutation.
- No live fare search, schedule inventory, or historical fare warehouse.
- No automatic production indexability or editorial review.
