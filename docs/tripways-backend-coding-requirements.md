# Tripways Backend Coding Requirements

## Boundaries

- SQL/RPC owns business invariants and transactional state.
- Next.js and Edge handlers follow: parse, validate, authorize, call RPC, normalize, log, respond.
- Do not duplicate graph ranking, publish eligibility, or indexability rules in transports.

## TypeScript

- Enable strict mode, `noImplicitAny`, `noImplicitReturns`, and `noUncheckedIndexedAccess`.
- Use `PascalCase` for types and `camelCase` for values/functions.
- Use stable `ERR_*` codes and `UPPER_SNAKE_CASE` log events.
- Keep files focused and avoid generic repository or factory layers without multiple real consumers.

## SQL

- Write all PostgreSQL and PL/pgSQL keywords in uppercase.
- Use `snake_case` for database objects, `p_` for parameters, and `v_` for local variables.
- Use two-space indentation and split multi-clause statements into readable lines.
- Align table column names and data types. Add a blank line before constraints and between distinct
  constraint blocks.
- Declare indexes explicitly with their access method, such as `USING btree` or intentional
  alternatives including `USING gin`.
- Place index `ON`, access method, and partial-index `WHERE` clauses on separate lines following the
  established `slofi-backend` layout.
- Format seed rows vertically with one value per line and explicit column lists.
- Use separator headers in SQL function files and group non-trivial `DECLARE` variables by role.
- Validate existence and domain invariants before mutation.
- Use constraints and transactions instead of duplicating correctness checks in application code.
- Set explicit `search_path` for privileged functions and schema-qualify referenced objects.
- Keep raw, operational, analytics, and public read responsibilities in separate schemas.
- Keep exactly one table definition per `sql_src/schema/<schema>/<table>.sql` file.
- Keep exactly one function definition per `sql_src/functions/<feature>/<function>.sql` file.
- Keep fixture and reference records under `supabase/seed`; do not place environment-specific data
  in schema, function, trigger, or migration files.
- Treat DML inside business functions and rollback-based SQL test setup as behavior and verification,
  not seed data.

## API and errors

- Use REST semantics, bounded pagination, and normalized query identity.
- Return the shared data/meta/error envelope.
- Never return raw database/provider errors or sensitive operational details.
- Include request ID, action, status, processed timestamp, and stable error code in structured logs.

## Security

- Expose only `public` and required platform schemas through the Data API.
- Enable RLS and explicit policies before grants.
- Keep secret keys server-side and exclude secrets, tokens, raw payloads, and full IP addresses from
  logs.
- Authenticate, authorize, rate-limit, and make privileged ingestion idempotent.

## Testing and Definition of Done

- Test parsers, validators, envelopes, ranking, publish gating, idempotency, and security boundaries.
- Run Prettier, TypeScript checks, Vitest, Deno checks/tests, SQL tests, security guards, and Next.js
  build as relevant.
- Rebuild the local database from migrations and seed before final database verification.
- Document skipped scope and the concrete condition that would justify adding it.
