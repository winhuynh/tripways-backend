# Tripways Supabase Basic Foundation Plan

**Goal:** Provide the smallest local Supabase foundation that is easy to understand and extend one
feature at a time.

## Current scope

1. Initialize the Git repository on `main` without committing.
2. Configure a local Supabase project on conflict-free ports.
3. Create empty `private`, `admin`, and `analytics` schemas. `public` remains Supabase-managed.
4. Keep one SQL object per source file under `supabase/sql_src`.
5. Add one PostgreSQL health function and one Edge health function as reference implementations.
6. Add a minimal empty seed and local verification commands.

## Explicitly deferred

- Domain tables such as airports, cities, airlines, and routes.
- Ingestion and provider adapters.
- Graph functions and route discovery.
- Next.js API and shared packages.
- Analytics and affiliate data models.
- CI, Redis, remote linking, and deployment.

Each deferred capability will receive its own small design and implementation step when the user is
ready to build and learn that feature.
