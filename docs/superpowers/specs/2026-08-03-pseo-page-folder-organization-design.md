# pSEO Page Folder Organization Design

## Goal

Organize pSEO SQL source files by page ownership so engineers can locate a page's schema and
functions without scanning one flat directory.

## Structure

Both `supabase/sql_src/schema/pseo` and `supabase/sql_src/functions/pseo` use the same single-level
ownership folders:

```text
pseo/
├── shared/
├── homepage/
├── city/
├── airport/
└── route/
```

`shared` owns publication orchestration, the generic page dispatcher, sitemap, cross-page internal
links, shared price estimates, and other objects with at least two page consumers. Page folders own
their page identity, content tables, read model, offline builders, and page-specific helpers.

## Constraints

- SQL object names and runtime API contracts do not change.
- The migration generator lists every source explicitly in dependency order.
- No SQL source file remains directly under either pSEO root.
- Tests and documentation reference the new physical paths.
- Generated migrations remain flat deterministic artifacts.

## Verification

Regenerate migrations, clean-reset local Supabase, run every SQL snippet, all Deno tests, strict
checks, formatting, RLS/grant audits, and assert that both pSEO roots contain zero direct SQL files.
