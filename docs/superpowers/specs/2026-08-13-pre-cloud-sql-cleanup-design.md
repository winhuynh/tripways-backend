# Pre-cloud SQL Cleanup Design

## Goal

Keep `supabase/sql_src` as a minimal, declarative, readable source of truth before the first cloud
deployment.

## Required invariants

- Every function source file defines exactly one function.
- No function in the exposed `public` schema uses `SECURITY DEFINER`.
- Every exposed table enables RLS after creation. This required PostgreSQL `ALTER TABLE` remains.
- Every protected object explicitly revokes default/client access and grants only its intended role.
  This deny-then-allow pattern remains because it is the security contract, not redundant mutation.
- Trigger installation keeps `DROP TRIGGER IF EXISTS` before `CREATE TRIGGER` because PostgreSQL has
  no `CREATE OR REPLACE TRIGGER`.
- Unused `place_aliases`, `pseo_internal_links`, and standalone IATA normalization helpers are
  removed until a real consumer exists.
- Page builders execute once per materialized read-model row.
- Publication computes lifecycle eligibility first and updates the page registry once.
- SQL files use repository headers and readable multi-line formatting.

## Verification

Static SQL contracts enforce the invariants. Generated migrations must include every remaining SQL
source exactly once. A clean local reset, privilege checks, SQL E2E, Edge checks, and all backend
tests must pass before staging deployment.
