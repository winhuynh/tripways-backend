# Public-safe pSEO Payload Design

## Goal

The public page and affiliate contracts must expose no database primary keys, foreign keys, raw
provider references, or publication UUIDs.

## Contract

- City identity exposes `name`, `slug`, `iata_code`, `timezone`, `currency_code`, and
  `primary_language` only.
- Airport identity exposes `iata`, `icao`, `name`, `slug`, `image_path`, and `timezone` only.
- City and airport route arrays use an explicit DTO containing `from`, `to`, `airline`,
  `observed_amount`, `currency_code`, `valid_until`, and `route_path`.
- Route observations expose `observation_ref` instead of the database UUID.
- `flight_route_prices.public_reference` is a unique, opaque, server-generated stable reference.
- Affiliate handoff accepts `observation_ref` and resolves it server-side.
- Public page metadata contains `canonical_path`, `is_indexable`, `noindex_reason`,
  `source_freshness_at`, `generated_at`, and an opaque `data_version` token.
- Public payloads never contain keys named `id`, ending in `_id`, or provider-only affiliate paths.

## Publication flow

Builders continue to compose page payloads during publication. Read models store both the public
page data and its public lifecycle metadata. `rpc_get_page` reads one current read-model row and
returns the stored metadata without exposing the publication primary key.

The public data-version token is `v_` plus a one-way digest of the internal publication UUID. It
remains consistent across all pages in one publication while not revealing the database key.

## Security

The public contract uses positive field allowlists rather than `to_jsonb(table_row)`. The affiliate
RPC remains service-role-only, validates the opaque reference format, and resolves only fresh,
published observations with an allowlisted partner destination.

## Verification

- SQL contract tests fail if builders serialize complete table rows or include internal ID keys.
- SQL E2E recursively scans City, Airport, and Route responses for forbidden keys and UUID values.
- Affiliate Edge tests require `observationRef` and reject UUID/database-ID input fields.
- Migrations are regenerated and the database is rebuilt before final E2E verification.
