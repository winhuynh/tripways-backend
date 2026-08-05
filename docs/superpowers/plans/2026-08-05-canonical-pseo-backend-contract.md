# Canonical pSEO Backend Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây typed backend schema và hai canonical public RPC cho bốn pSEO page, đồng thời xoá toàn bộ duplicate/legacy pSEO functions.

**Architecture:** Core aviation tables tiếp tục là nguồn facts; page-specific typed content tables và FAQ tables tạo immutable read models theo publication version. Public API chỉ còn `rpc_get_page`, `rpc_search_routes`, `rpc_search_places`, `rpc_get_sitemap` cùng các ingestion/publication capabilities khác biệt.

**Tech Stack:** PostgreSQL, Supabase CLI, PL/pgSQL, Deno, TypeScript.

---

### Task 1: Canonical source contract tests

**Files:**

- Create: `supabase/functions/_shared/security/tests/canonical_pseo_sql_contract.test.ts`
- Modify: `package.json`

- [x] Viết test đọc `supabase/sql_src` và yêu cầu typed content tables, `rpc_get_page.sql`, `rpc_search_routes.sql` tồn tại.
- [x] Yêu cầu không còn `_v2`, split city RPC hoặc page-specific public RPC trong SQL source/Edge handlers.
- [x] Yêu cầu canonical functions revoke public browser roles và grant chỉ `service_role`.
- [x] Chạy `deno test --allow-read ...canonical_pseo_sql_contract.test.ts` và xác nhận RED vì canonical files chưa tồn tại.

### Task 2: Typed page content schema

**Files:**

- Create: `supabase/sql_src/schema/pseo/homepage/homepage_pages.sql`
- Create: `supabase/sql_src/schema/pseo/homepage/homepage_featured_origins.sql`
- Create: `supabase/sql_src/schema/pseo/homepage/homepage_featured_routes.sql`
- Create: `supabase/sql_src/schema/pseo/homepage/homepage_content_sections.sql`
- Create: `supabase/sql_src/schema/pseo/homepage/homepage_faqs.sql`
- Create: `supabase/sql_src/schema/pseo/city/city_content_sections.sql`
- Create: `supabase/sql_src/schema/pseo/airport/airport_content_sections.sql`
- Modify: existing City/Airport/Route content and FAQ tables where source/version constraints are missing.
- Modify: `supabase/sql_src/schema/route_discovery/route_search_options.sql`

- [x] Thêm typed root/content tables với one-table-per-file, constraints, RLS và service-role grants.
- [x] Thêm source, verification, review và data-version fields cho page-specific facts/content/FAQ.
- [x] Bổ sung country/region/domestic/departure-time/one-way-price fields vào published route projection.
- [x] Chạy source contract test và schema format checks.

### Task 3: Canonical page and route-search functions

**Files:**

- Create: `supabase/sql_src/functions/pseo/shared/rpc_get_page.sql`
- Create: `supabase/sql_src/functions/route_discovery/rpc_search_routes.sql`
- Modify: `supabase/sql_src/functions/pseo/shared/refresh_page_read_models.sql`
- Modify: `supabase/functions/v1/page/query/index.ts`
- Modify: `supabase/functions/v1/route-search/query/index.ts`
- Modify: related Edge handler tests and SQL snippets.

- [x] `rpc_get_page` validate exact input keys, resolve current publication và trả immutable payload.
- [x] `rpc_search_routes` hỗ trợ bốn scope, keyset pagination và canonical filters/facets.
- [x] Publication composer tạo payload typed cho Homepage/City/Airport/Route từ page-specific tables và canonical facts.
- [x] Chuyển Edge handlers sang canonical function names.
- [x] Chạy Edge tests và focused SQL contract checks.

### Task 4: Remove duplicate and legacy functions

**Files:**

- Delete: `supabase/sql_src/functions/pseo/shared/rpc_get_page_v2.sql`
- Delete: `supabase/sql_src/functions/route_discovery/rpc_search_route_options_v2.sql`
- Delete: `supabase/sql_src/functions/pseo/route/rpc_search_route_options.sql`
- Delete: page-specific public RPC files under `functions/pseo/homepage`, `city`, `airport`, `route` listed in the approved spec.
- Modify/Delete: obsolete SQL snippets and source-contract tests.

- [x] Dependency scan trước khi xoá.
- [x] Xoá only duplicate public functions; giữ private helper có một trách nhiệm rõ.
- [x] Chuyển mọi snippet/test sang canonical RPC.
- [x] Chạy source scan để xác nhận không còn `_v2` hoặc legacy names ngoài historical docs.

### Task 5: Regenerate and verify database

**Files:**

- Regenerate: `supabase/migrations/*.sql` bằng `scripts/regenerate-supabase-migrations.sh`.

- [x] Chạy formatter trên SQL/TypeScript đã đổi.
- [x] Regenerate deterministic migrations từ `sql_src`.
- [x] Chạy `pnpm supabase:reset` để rebuild local database và seed.
- [x] Chạy canonical SQL behavior, RLS/privilege, Edge format/check/tests và `pnpm verify:p0a`.
- [x] Chạy `git diff --check` và final duplicate/dependency scan.

### Task 6: Handoff

- [x] Cập nhật checkbox plan theo evidence thực tế.
- [x] Báo `implemented`, `skipped`, `add when` và các verification command/output.
- [x] Không commit, push hoặc deploy.
