# pSEO Page Folder Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize pSEO SQL source files into shared, homepage, city, airport, and route folders
without changing database behavior.

**Architecture:** Page-owned tables/functions move together beneath matching folders. Cross-page
orchestration and contracts move beneath `shared`; the migration generator preserves explicit
dependency order.

**Tech Stack:** Bash migration generator, PostgreSQL 17, Supabase CLI, Deno TypeScript tests.

---

### Task 1: Lock the folder invariant

- [ ] Add a filesystem contract test requiring the five folders and zero direct SQL files.
- [ ] Run the test before moves and observe failure from the flat layout.

### Task 2: Move schema sources by ownership

- [ ] Move shared registry/publication tables to `schema/pseo/shared`.
- [ ] Move Homepage, City, Airport, and Route tables to their matching folders.
- [ ] Preserve one table per file and all SQL content unchanged.

### Task 3: Move function sources by ownership

- [ ] Move cross-page orchestration, dispatcher, sitemap, and shared price/search helpers to
      `functions/pseo/shared`.
- [ ] Move page builders and page-specific helpers to their matching folders.

### Task 4: Update consumers

- [ ] Replace every generator, test, script, and documentation source path.
- [ ] Confirm no old flat pSEO source path remains.

### Task 5: Verify determinism and behavior

- [ ] Regenerate all migrations only from `sql_src`.
- [ ] Clean-reset local Supabase and run all SQL snippets.
- [ ] Run Deno tests/checks, format checks, RLS/grant audits, and `git diff --check`.
- [ ] Do not commit, push, or deploy without explicit user approval.
