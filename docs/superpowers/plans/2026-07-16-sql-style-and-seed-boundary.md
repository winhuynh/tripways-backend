# SQL Style and Seed Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standardize every repository SQL file with uppercase PostgreSQL syntax and enforce a clear seed-data boundary without changing behavior.

**Architecture:** Maintain `supabase/sql_src` as the readable canonical source, keep equivalent migration statements stylistically aligned, and isolate fixture records under `supabase/seed`. Existing rollback-based verification snippets and business DML remain in their responsibility-specific files.

**Tech Stack:** PostgreSQL 17, PL/pgSQL, Supabase CLI, Deno contract tests.

---

## File map

- `docs/codex_work_rules.md`: mandatory repository-wide SQL style and seed rule.
- `docs/tripways-backend-coding-requirements.md`: implementation-level SQL formatting requirements.
- `supabase/sql_src/**/*.sql`: canonical schema, function, and trigger formatting.
- `supabase/migrations/*.sql`: migration formatting aligned with canonical sources.
- `supabase/seed/*.sql`: fixture data formatted with the same SQL conventions.
- `supabase/snippets/*.sql`: verification SQL formatted without moving rollback-based test setup.

### Task 1: Add enforceable coding rules

- [ ] Add uppercase keyword, explicit index, indentation, and seed-boundary rules to both coding-rule documents.
- [ ] State explicitly that DML inside functions is business logic and rollback-based snippet setup is test data, not seed data.
- [ ] Run `git diff --check` and confirm exit code 0.

### Task 2: Format canonical SQL sources

- [ ] Format every file returned by `rg --files supabase/sql_src -g '*.sql'`.
- [ ] Use uppercase PostgreSQL and PL/pgSQL keywords while preserving lowercase `snake_case` object names.
- [ ] Rewrite index declarations using explicit `USING btree` or the intentional access method such as `USING gin`.
- [ ] Run Deno SQL contract tests and confirm all assertions pass without semantic updates.

### Task 3: Align migrations

- [ ] Format all files returned by `rg --files supabase/migrations -g '*.sql'`.
- [ ] Preserve migration order, objects, privileges, RLS, policies, function security, and trigger behavior.
- [ ] Confirm no fixture/reference record insertion exists at migration top level.
- [ ] Run `supabase db reset --local --yes` and confirm all migrations and seeds apply.

### Task 4: Format seeds and verification snippets

- [ ] Format every SQL file under `supabase/seed` and `supabase/snippets`.
- [ ] Keep fixture records only in `supabase/seed`.
- [ ] Keep snippet setup inside its transaction and preserve `ROLLBACK` cleanup.
- [ ] Execute every snippet with `psql -v ON_ERROR_STOP=1` and confirm exit code 0.

### Task 5: Full verification and semantic review

- [ ] Run `deno test --config supabase/functions/deno.json --allow-all supabase/functions`.
- [ ] Run database lint plus security and performance advisors with `--fail-on error`.
- [ ] Run `git diff --check`.
- [ ] Scan migrations and canonical sources for top-level fixture DML and inspect the final diff for semantic changes.
- [ ] Report completion without committing, pushing, or deploying.
