# Codex Workflow Rules

## 1. Review-first reporting

When reviewing or summarizing work, report findings and risks first, then decisions, verification
evidence, and next steps. Preserve decision trace instead of reporting only completion.

## 2. Scope and state safety

- Never revert user changes without explicit instruction.
- Do not use destructive Git or database commands without explicit approval.
- Stop and ask when unexpected changes directly conflict with the task.
- Do not commit, push, link, or deploy automatically; ask the user first.

## 3. Required repository context

Before coding, read this file and `docs/tripways-backend-coding-requirements.md`. When completing a
task, state which relevant requirements were followed and identify any intentional exclusions.

## 4. Code and comment conventions

- Use English for code, identifiers, comments, and file-level headings.
- Comments explain intent, flow, decisions, or non-obvious edge cases, never obvious syntax.
- Keep formatting and naming consistent across every touched code file.
- SQL functions use clear `Function / Purpose / Responsibilities / Notes` headers and `STEP xx`
  comments for significant business flows.
- Write PostgreSQL and PL/pgSQL keywords in uppercase. Keep database object names, parameters, and
  variables in `snake_case`.
- Format SQL with two-space indentation and one readable clause per line. Use explicit index
  declarations, including the access method, for example:

  ```sql
  CREATE UNIQUE INDEX data_sources_code_key
  ON admin.data_sources USING btree (code);
  ```

- Follow the readable table layout used by `slofi-backend`: align column names and data types,
  separate the column list from constraints, and leave one blank line between constraint blocks.
- Put `ON`, `WHERE`, `USING`, `FROM`, `TO`, and other major multi-line clauses on their own readable
  lines instead of indenting an entire statement into one dense row.
- Format multi-row seed data vertically. Each row uses its own parenthesized block, with one value
  per line in the same order as the explicit column list.
- SQL function files use separator headers and group non-trivial `DECLARE` variables by role, such
  as `Auth`, `Input`, `Resolved entities`, and `Result`.
- TypeScript uses section comments only where orchestration, fallback, idempotency, or error
  normalization would otherwise be hard to scan.

## 5. Architecture boundaries

- Postgres/RPC is the source of truth for domain invariants, publishing, graph queries, and
  indexability.
- Next.js Route Handlers are thin public read transports and own HTTP caching and envelopes.
- Edge Functions are thin privileged transports for ingestion and event writes.
- Raw provider data stays outside exposed schemas.
- Reuse shared contracts and helpers only when they remove real duplication or boundary risk.

## 6. Supabase and migration safety

- Enable RLS on every table in an exposed schema before granting access.
- Use explicit policies and least-privilege grants; public clients never receive domain writes.
- Never expose service-role or secret keys to clients.
- Do not place `security definer` functions in exposed schemas.
- Privileged functions set an explicit `search_path`.
- Treat `supabase/sql_src` as the single source of truth and
  `supabase/migrations` as deterministic generated output.
- Never edit a generated migration directly. While the project has no deployed migration history,
  regenerate the complete clean migration foundation with
  `scripts/regenerate-supabase-migrations.sh`.
- Store each table in its own `supabase/sql_src/schema/<feature>/<table>.sql` file.
- Store each PostgreSQL function in its own
  `supabase/sql_src/functions/<feature>/<function>.sql` file.
- Keep fixtures and reference data only in `supabase/seed`; the migration generator must never
  include seed files.
- After regeneration, reset local Supabase and run database, RLS, privilege, and contract checks
  before considering the source change complete.
- Group Edge Function code by feature and operation under
  `supabase/functions/v1/<feature>/<operation>/`.

## 7. Data-source trust

- Every published route has approved source rights, status, confidence, and freshness.
- Development fixtures can never become production or SEO-indexable data.
- OpenFlights is prohibited in production, API, sitemap, and local fixture data.
- Missing frequency and seasonality remain unknown rather than becoming zero or year-round.
- Store fixture and reference records only under `supabase/seed`; never embed them in schema,
  function, trigger, or migration sources.
- DML inside PostgreSQL functions remains with the function when it implements business behavior.
  Rollback-based setup data remains in SQL verification snippets and is not seed data.

## 8. Testing and verification

- Use test-first development for behavior changes and non-trivial logic.
- Run format, lint, typecheck, relevant tests, build, and database/security checks before claiming
  completion.
- Verify database changes using local queries against a database rebuilt from migrations and seed.
- A test must be observed failing for the intended reason before production behavior is added.

## 9. Senior minimalism and YAGNI

Use the first adequate option in this order: remove the need, reuse repo code, standard library,
native platform feature, installed dependency, direct code, then minimal custom abstraction. Do not
add speculative factories, interfaces with one non-boundary implementation, optional modes, cache
layers, or future-domain scaffolding.

## 10. Completion format

Use: `implemented: X; skipped: Y; add when: Z`. Include verification evidence and do not hide
unverified or blocked work.
