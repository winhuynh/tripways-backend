# Observed Price Affiliate Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a fresh observed-price card and safe click-to-Aviasales handoff while keeping provider governance in `admin.data_sources`.

**Architecture:** Provider provenance becomes bounded source/provider codes, operational receipts stay private, and route-page read models expose opaque observation metadata only. A same-origin Next.js handler calls a dedicated Edge handoff boundary before browser navigation.

**Tech Stack:** PostgreSQL/Supabase, Deno Edge Functions, Next.js 16, React 19, Vitest.

---

### Task 1: Contract the focused admin boundary

**Files:** backend ingestion/flight SQL contract tests and schema sources.

- [ ] Add failing contracts retaining `admin.data_sources` and `admin.ourairports_denylist` while removing redundant log tables.
- [ ] Run focused Deno contracts and observe legacy-table failures.
- [ ] Remove `ingestion_runs` and `ingestion_issues`; keep `admin.data_sources` unchanged.
- [ ] Update canonical and observation foreign-key fields plus ingestion functions.
- [ ] Run contracts and local database reset.

### Task 2: Publish frontend-safe observations

**Files:** route page builder/read models and ingestion publication flow.

- [ ] Add a failing route-payload contract for opaque ID, amount, currency, dates, freshness, and no affiliate path.
- [ ] Select only published/unexpired observations and keep fixed disclaimer text.
- [ ] Ensure local observation refresh can rebuild the disposable publication.
- [ ] Verify the SGN–London read model contains the current observation.

### Task 3: Add the handoff Edge boundary

**Files:** `supabase/functions/v1/flight-affiliate-handoff/*`, config, shared SQL RPC.

- [ ] Add failing request/handler tests for UUID validation and safe errors.
- [ ] Implement a POST-only Edge Function calling the fixed-host RPC with service role.
- [ ] Verify expired, unknown, and valid observations.

### Task 4: Render and navigate from the frontend

**Files:** route-page domain/DTO/presentation, server environment, Next API route.

- [ ] Add failing DTO tests for observed-price and unavailable states.
- [ ] Add failing component tests for “Recently observed”, disclaimer, and “Check latest price”.
- [ ] Implement a focused client CTA and same-origin server route; never pass service credentials to props.
- [ ] Style responsive price cards within the existing route-page visual system.

### Task 5: Verify end to end

- [ ] Run backend format, type checks, contracts, migration regeneration, and local reset.
- [ ] Republish current OurAirports and Travelpayouts data and rebuild local read models.
- [ ] Run frontend lint, typecheck, tests, production build, and responsive browser checks.
- [ ] Confirm the CTA resolves only through Tripways and redirects to the allowlisted Aviasales host.
