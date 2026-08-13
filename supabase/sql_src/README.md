# SQL sources

This directory is the single source of truth for the Tripways database.

## Organization

- `schema/<feature>/<table>.sql`: one table per file, grouped by product feature.
- `functions/_shared/<function>.sql`: helpers reused by multiple feature RPCs.
- `functions/<feature>/<function>.sql`: one PostgreSQL function per file.
- `triggers/<feature>/<trigger>.sql`: one trigger per file.
- `supabase/seed/*.sql`: fixture and reference data; seed data never belongs in `sql_src`.

The folder name represents the product feature, not necessarily the PostgreSQL schema. For example,
`schema/flight_routing/airports.sql` owns `public.airports`.

Public RPCs own transport contracts and orchestration. Reusable parsing, normalization, resolution,
and envelope behavior belongs in least-privilege functions under the `admin` schema. Do not
extract single-caller query blocks merely to make an RPC shorter.

## Migration workflow

Do not edit files under `supabase/migrations` manually. After changing a source file, regenerate the
complete local migration set:

```bash
pnpm supabase:migrations:regenerate
```

The generator is deterministic, includes every SQL source exactly once, and writes source markers
into each migration. Because the project has no production migration history yet, migrations remain
a clean rebuildable foundation rather than an incremental patch chain.

Then verify from an empty local database:

```bash
pnpm supabase:reset
```
