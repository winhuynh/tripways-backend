# SQL Style and Seed Boundary Design

## Goal

Standardize every SQL file in the repository with readable uppercase PostgreSQL syntax while
preserving database behavior. Keep fixture and reference records in `supabase/seed` instead of
schema, function, trigger, or migration sources.

## Scope

The formatting pass covers every `.sql` file under:

- `supabase/sql_src`
- `supabase/migrations`
- `supabase/seed`
- `supabase/snippets`

TypeScript, TOML, and Markdown formatting are outside this change, except for the repository coding
rules that define the new SQL convention.

## Canonical SQL Style

- Write PostgreSQL keywords in uppercase, including DDL, DML, PL/pgSQL control flow, privileges,
  constraint operators, and function attributes.
- Keep schemas, tables, columns, functions, parameters, variables, indexes, constraints, roles, and
  policies in `snake_case`.
- Schema-qualify database objects at feature and security boundaries.
- Use explicit, reviewable index statements. The canonical shape is:

```sql
CREATE UNIQUE INDEX data_sources_code_key
  ON admin.data_sources USING btree (code);
```

- Use consistent two-space indentation and one clause per line when a statement does not remain
  immediately readable on one line.
- Preserve English file headers and comments that explain intent rather than syntax.
- Keep each table and PostgreSQL function in its existing single-purpose source file.

## Seed Boundary

Fixture or reference records belong only in `supabase/seed`. Schema sources and migrations must not
embed environment-specific example records.

The following DML is not seed data and remains in its responsibility-specific file:

- `INSERT`, `UPDATE`, or `DELETE` inside PostgreSQL functions when it implements business behavior;
- setup data inside rollback-based SQL verification snippets;
- cleanup statements inside verification snippets.

The current migrations contain business logic but no fixture record insertion. The existing Route
Discovery fixture remains in `supabase/seed/flight_routing_fixture.sql`.

## Migration Consistency

Existing migrations will be reformatted in place because this repository is still establishing its
foundation and the user explicitly requested whole-repository consistency. Formatting must not
change object definitions, execution order, privileges, RLS, function security, or data behavior.

`supabase/sql_src` remains the maintainable source. Equivalent statements duplicated in migrations
must use the same capitalization and layout wherever practical.

## Coding Rules

Add mandatory SQL capitalization, explicit index formatting, and seed-boundary requirements to:

- `docs/codex_work_rules.md`
- `docs/tripways-backend-coding-requirements.md`

Future SQL changes must follow these rules before migrations are considered reviewable.

## Verification

After formatting:

1. Rebuild the local database from all migrations and seed files.
2. Run every SQL verification snippet.
3. Run Deno contract and Edge tests.
4. Run database lint plus security and performance advisors.
5. Confirm formatting introduced no whitespace errors with `git diff --check`.
6. Review the final diff for semantic changes and fixture records outside `supabase/seed`.

## Intentional Exclusions

- No schema redesign or new database objects.
- No SQL formatter dependency.
- No movement of business DML out of PostgreSQL functions.
- No movement of rollback-based test setup out of SQL snippets.
- No automatic commit, push, or deployment.
