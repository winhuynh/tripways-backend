# Singapore City pSEO Fixture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seed a complete Singapore city page through the existing generic pSEO pipeline.

**Architecture:** Extend only development fixture SQL and verification SQL. Reuse all existing schemas, helper functions, RPCs, and Edge transports without city-specific application logic.

**Tech Stack:** PostgreSQL, Supabase CLI, psql

---

### Task 1: Define the Singapore read-model contract

**Files:**

- Modify: `supabase/snippets/e2e_city_page_read_models.sql`

- [ ] Add assertions for Singapore overview, airport, destinations, route map, quick facts, FAQ, and internal links.
- [ ] Run the SQL verification and observe failure because Singapore lacks `city_pages` content and originating routes.

### Task 2: Add the complete development fixture

**Files:**

- Modify: `supabase/seed/city_pseo_fixture.sql`

- [ ] Add Singapore city-page content using the existing Singapore pSEO page and city IDs.
- [ ] Add Changi airport content, recurring Singapore-origin routes, supporting airlines/schedules, FAQ, and internal links using the existing vertical seed format.
- [ ] Keep all page records non-indexable and development-only.

### Task 3: Rebuild and verify

**Files:**

- No new production files.

- [ ] Reset local Supabase from clean migrations and seed.
- [ ] Run database, read-model, RLS, privilege, and formatting checks.
- [ ] Verify the Edge read transport and `/flights-from/singapore`.

No commit or push is performed because repository rules prohibit automatic integration.
