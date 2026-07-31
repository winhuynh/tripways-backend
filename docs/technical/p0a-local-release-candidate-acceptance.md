# P0A Local Release Candidate Acceptance

**Date:** 2026-07-30  
**Result:** 11/12 capabilities demonstrated locally  
**Default tests:** Offline and deterministic  
**Indexing:** Disabled for all P0A pages

## Capability Matrix

| #   | Capability                                               | Result  | Evidence                                                                                                                              |
| --- | -------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Rebuild local Supabase from migrations and seed          | Pass    | `bash scripts/regenerate-supabase-migrations.sh`; `supabase db reset --local --yes`                                                   |
| 2   | Ingest a valid mock-provider batch                       | Pass    | Provider/parser/service tests plus `supabase/snippets/e2e_base_data_ingestion.sql` publish a deterministic canonical batch            |
| 3   | Reject invalid data without damaging good data           | Pass    | SQL E2E verifies unchanged canonical counts; parser covers missing fields, invalid coordinates, duplicates, and unresolved references |
| 4   | Replay a batch idempotently                              | Pass    | SQL E2E returns `ERR_INGESTION_BATCH_DUPLICATE` and preserves one canonical record per identity                                       |
| 5   | Smoke an approved real API with bounded data             | Blocked | Command is implemented as `npm run smoke:approved-api`, but no approved provider URL/credentials were supplied                        |
| 6   | Homepage links only to existing content                  | Pass    | Vitest inventory contract and browser smoke for Bangkok, Singapore, and BKK inventory                                                 |
| 7   | City page loads end to end                               | Pass    | Production server + local public-read handler smoke rendered Bangkok content, filtered state, canonical base URL, and `noindex`       |
| 8   | Airport page loads end to end                            | Pass    | Production server + local public-read handler smoke rendered BKK content and intentional inbound empty state                          |
| 9   | Route filters return results or an empty state           | Pass    | Existing route/filter tests plus browser smoke for city airline and airport direction filters                                         |
| 10  | Route map loads or has an intentional fallback           | Pass    | Browser smoke rendered “Route map is temporarily unavailable” while preserving homepage content                                       |
| 11  | Loading, not-found, and dependency errors terminate      | Pass    | Existing loading/not-found tests and browser smoke of bounded city/airport dependency-error UI on mobile                              |
| 12  | Format, lint, typecheck, tests, security, and build pass | Pass    | Backend 98/98 Deno tests; web 79/79 Vitest tests; Deno format/check; ESLint; TypeScript; SQL E2E; Next.js production build            |

## Verification Summary

Backend:

- Migration regeneration completed and included every SQL source exactly once.
- Clean local database rebuild completed through all migrations and seed files.
- Deno format checked 65 files.
- Deno checked all required Edge entrypoints, including city, airport, and ingestion.
- Deno test result: 98 passed, 0 failed.
- SQL ingestion E2E result: `BEGIN`, `DO`, `ROLLBACK`.

Web:

- ESLint passed.
- TypeScript `--noEmit` passed.
- Vitest result: 36 files, 79 tests passed.
- Next.js 16 production build compiled, typechecked, generated static routes, and retained dynamic
  city/airport SSR routes.
- Desktop homepage browser smoke passed.
- Mobile 390×844 smoke showed no horizontal overflow.
- City filtered URL canonicalized to `/flights-from/bangkok` and emitted `noindex`.
- Airport filtered URL canonicalized to `/airports/suvarnabhumi-bkk` and emitted `noindex`.
- Newsletter controls were disabled and labelled preview-only.

## Edge Runtime Note

The bundled Supabase Edge Runtime attempted to fetch
`https://jsr.io/@panva/jose/meta.json` and received HTTP 403, including when run outside the
filesystem sandbox. To keep the UI smoke deterministic, the same checked-in city and airport Edge
handlers were mounted in a temporary local Deno harness and called the rebuilt local Supabase REST
RPC boundary with service-role credentials held only in the process environment.

This runtime dependency-download issue does not affect the default offline unit, contract, SQL, or
build suites. It must be resolved before P0B by using a runtime image with the locked dependency
available offline or an approved network path.

## Security and Trust Evidence

- Raw records remain in `private`; operational records remain in `admin`.
- Public clients have no canonical writes and no raw/admin access.
- The exposed ingestion RPC wrapper is security-invoker and executable only by `service_role`.
- The privileged publication function is in `private` with an explicit empty `search_path`.
- Ingestion rejects arbitrary provider URLs and unknown source codes/modes.
- Worker and IP rate-limit subjects are hashed.
- Logs omit raw payloads, full IP addresses, bearer tokens, and secrets.
- No service-role variable uses a `NEXT_PUBLIC_*` name.
- Fixture and approved-API data remain development-only, production-disabled, SEO-disabled, and
  excluded from the sitemap.

## Proposed P0B Source State

The working trees are intentionally uncommitted because repository rules prohibit automatic commits:

- Backend base commit: `2c69d998499eb702ca15f89119aa420453e4ef7e`
- Web base commit: `d5bde3a7a5f7faedf5dd54c4e05ed597b68de460`

The immutable P0B source state must be recorded as the two new commit SHAs after the owner reviews and
authorizes commits. P0B must deploy those exact SHAs without additional logic changes.

## Remaining Acceptance Action

Capability 5 becomes pass when the owner supplies an approved HTTPS provider URL, bounded source
rights, and any required local credential, then runs:

```bash
npm run smoke:approved-api
```

The smoke command is opt-in and is not part of the default offline verification suite.
