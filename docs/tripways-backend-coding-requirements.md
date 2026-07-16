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

- Use `snake_case` for database objects, `p_` for parameters, and `v_` for local variables.
- Validate existence and domain invariants before mutation.
- Use constraints and transactions instead of duplicating correctness checks in application code.
- Set explicit `search_path` for privileged functions and schema-qualify referenced objects.
- Keep raw, operational, analytics, and public read responsibilities in separate schemas.
- Keep exactly one table definition per `sql_src/schema/<schema>/<table>.sql` file.
- Keep exactly one function definition per `sql_src/functions/<feature>/<function>.sql` file.

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
