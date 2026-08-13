# Observed Price Affiliate Frontend Design

## Goal

Expose fresh Travelpayouts observations as clearly labelled reference prices on Tripways route
pages. A user must explicitly request the latest price before Tripways resolves an allowlisted
Aviasales affiliate handoff URL. Cached observations are never described as live inventory.

## Data and admin boundary

Keep `admin.data_sources` as the provider rights and provenance registry and keep
`admin.ourairports_denylist` for reviewed exclusions. Remove only the redundant operational log
tables `admin.ingestion_runs` and `admin.ingestion_issues`. `admin.raw_import_batches` continues
to own checksum, idempotency, and batch status.

## Read flow

`flight_content_observations` is the source of fresh observed prices. Route-page payloads include
only published, unexpired rows with amount, currency, departure date, observation time, expiry,
and an opaque observation ID. They never include `affiliate_path`.

The Next.js route page renders “Recently observed from …” with a freshness disclaimer. An
accessible client CTA posts the opaque ID to a same-origin Next.js route handler. That handler
calls a dedicated Supabase Edge Function, which invokes the fixed-host handoff RPC. Only then does
the browser navigate to the returned Aviasales URL.

## Refresh behavior

Successful Travelpayouts publication replaces the provider's current observation set. Page data
must not be cached beyond observation validity. The page read model publication is rebuildable;
the local refresh workflow republishes it after ingestion so new observations become visible.

## Failure behavior

Missing/expired/unlicensed observations render no amount. Handoff rejects malformed UUIDs,
expired rows, missing affiliate paths, and any provider other than Travelpayouts. Frontend failures
remain on Tripways and show a retry-safe message without exposing provider details.

## Verification

Use SQL contract tests for schema/grants/freshness, Edge tests for handoff validation, frontend DTO
and component tests for labels/fallbacks, a local Supabase reset, and a browser check of the SGN to
London route using its real cached observation.
