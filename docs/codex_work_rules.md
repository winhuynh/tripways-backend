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
- Iterate through maintainable `supabase/sql_src` files, generate migrations through the Supabase
  CLI, and verify on local Supabase before considering a schema change complete.
- Store each table in its own `supabase/sql_src/schema/<schema>/<table>.sql` file.
- Store each PostgreSQL function in its own
  `supabase/sql_src/functions/<feature>/<function>.sql` file.
- Group Edge Function code by feature and operation under
  `supabase/functions/v1/<feature>/<operation>/`.

## 7. Data-source trust

- Every published route has approved source rights, status, confidence, and freshness.
- Development fixtures can never become production or SEO-indexable data.
- OpenFlights is prohibited in production, API, sitemap, and local fixture data.
- Missing frequency and seasonality remain unknown rather than becoming zero or year-round.

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
