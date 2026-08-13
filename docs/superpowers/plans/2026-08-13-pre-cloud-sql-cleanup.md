# Pre-cloud SQL Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the SQL source minimal, declarative, consistently formatted, and safe for the first cloud deployment.

**Architecture:** Preserve PostgreSQL-required RLS and trigger statements while removing unused objects and redundant execution. Static contracts protect file ownership, privilege boundaries, and source cleanliness.

**Tech Stack:** PostgreSQL, Supabase, Deno contract tests, Bash migration generator

---

### Task 1: Add SQL cleanliness contracts

- [ ] Assert one function per source file.
- [ ] Assert exposed functions never use `SECURITY DEFINER`.
- [ ] Assert removed objects have no source files.
- [ ] Assert page builders run once and publication lifecycle uses one registry update.

### Task 2: Remove unused objects and split mixed ownership

- [ ] Remove `place_aliases`, `pseo_internal_links`, and unused IATA normalizers.
- [ ] Split the price-publication RPC wrapper into its own source file.
- [ ] Remove duplicate schema usage grants.

### Task 3: Simplify execution flow and formatting

- [ ] Build each materialized payload once through a lateral result.
- [ ] Compute publication eligibility and update registry lifecycle once.
- [ ] Reformat dense SQL files and add consistent function headers.

### Task 4: Rebuild and verify

- [ ] Regenerate migrations and reset the local database.
- [ ] Run static contracts, Edge checks, all Deno tests, SQL E2E, privilege checks, and diff checks.
- [ ] Leave changes uncommitted and undeployed.
