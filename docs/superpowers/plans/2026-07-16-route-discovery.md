# Route Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng vertical feature Route Discovery chạy end-to-end trên fixture, hỗ trợ direct và
one-stop routes, schedule compatibility, filters, facets, stable ranking và Edge query boundary.

**Architecture:** `flight_routes` giữ network topology, `flight_services` giữ schedule pattern và
`route_options` là read model được rebuild từ hai source tables. PostgreSQL sở hữu compatibility,
filtering và ranking; Edge Function chỉ validate request, gọi RPC và chuẩn hóa HTTP response.

**Tech Stack:** Supabase Postgres 17, SQL/PLpgSQL, Supabase Edge Functions, Deno 2, TypeScript.

---

## File map

- `supabase/sql_src/schema/public/flight_services.sql`: một schedule pattern cho một route/flight.
- `supabase/sql_src/schema/public/route_options.sql`: read model direct/one-stop có thể filter.
- `supabase/sql_src/functions/route_discovery/calculate_layover_minutes.sql`: helper tính layover tại
  connection airport từ local schedule times.
- `supabase/sql_src/functions/route_discovery/refresh_route_options.sql`: rebuild read model trong
  transaction hiện tại.
- `supabase/sql_src/functions/route_discovery/rpc_search_routes.sql`: validate filter, query, rank,
  paginate và trả facets.
- `supabase/seed/flight_routing_fixture.sql`: fixture development-only có direct, valid one-stop và
  invalid connection candidates.
- `supabase/functions/v1/route-discovery/query/`: Edge transport theo pattern feature/operation.
- `supabase/functions/_shared/security/tests/route_discovery_sql_contract.test.ts`: source contract
  và security checks.
- `supabase/snippets/test_route_discovery.sql`: database behavior test có rollback.

### Task 1: Schedule pattern schema

**Files:**
- Create: `supabase/functions/_shared/security/tests/route_discovery_sql_contract.test.ts`
- Create: `supabase/sql_src/schema/public/flight_services.sql`
- Create: `supabase/migrations/<timestamp>_route_discovery.sql`

- [ ] **Step 1: Viết contract test fail cho `flight_services`**

Test phải assert một table/file, FK tới `flight_routes`, flight number, validity window, days
`1..7`, local times, arrival offset, duration, source lineage, RLS và không có client grants.

```ts
Deno.test('flight services preserve schedule pattern and source lineage', async () => {
  const sql = await readSource('schema/public/flight_services.sql');
  assert.ok(sql.includes('create table public.flight_services'));
  assert.ok(sql.includes('flight_route_id uuid not null references public.flight_routes (id)'));
  assert.ok(sql.includes('flight_number text not null'));
  assert.ok(sql.includes('valid_from date not null'));
  assert.ok(sql.includes('valid_to date not null'));
  assert.ok(sql.includes('departure_local_time time not null'));
  assert.ok(sql.includes('arrival_local_time time not null'));
  assert.ok(sql.includes('duration_minutes integer not null'));
  assert.ok(sql.includes('alter table public.flight_services enable row level security'));
});
```

- [ ] **Step 2: Chạy RED test**

Run:

```bash
deno test --config supabase/functions/deno.json --allow-read \
  supabase/functions/_shared/security/tests/route_discovery_sql_contract.test.ts
```

Expected: FAIL vì `flight_services.sql` chưa tồn tại.

- [ ] **Step 3: Tạo `flight_services` tối thiểu**

Table dùng UUID PK và các field: `flight_route_id`, `operating_airline_id`,
`marketing_airline_id`, `flight_number`, `valid_from`, `valid_to`, `days_of_week`,
`departure_local_time`, `arrival_local_time`, `arrival_day_offset`, `duration_minutes`,
`aircraft_type`, `confidence_score`, `source_id`, `source_record_id`, `last_verified_at`, timestamps.

Constraints bắt buộc:

```sql
check (valid_from <= valid_to)
check (cardinality(days_of_week) between 1 and 7)
check (days_of_week <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[])
check (arrival_day_offset between 0 and 2)
check (duration_minutes between 1 and 1440)
check (confidence_score between 0 and 1)
unique (source_id, source_record_id)
```

RLS bật; `anon`/`authenticated` bị revoke; `service_role` chỉ có CRUD.

- [ ] **Step 4: Tạo migration bằng CLI và reset local**

Run:

```bash
supabase migration new route_discovery
supabase db reset --local --yes
```

Expected: migration apply và seed hoàn tất không lỗi.

- [ ] **Step 5: Chạy GREEN test và advisors**

```bash
deno test --config supabase/functions/deno.json --allow-read \
  supabase/functions/_shared/security/tests/route_discovery_sql_contract.test.ts
supabase db lint --local --schema public --fail-on error
supabase db advisors --local --type security --fail-on error
```

Expected: PASS, không có schema/security error.

### Task 2: Deterministic route-discovery fixture

**Files:**
- Create: `supabase/seed/flight_routing_fixture.sql`
- Modify: `supabase/config.toml`
- Create: `supabase/snippets/test_route_discovery_fixture.sql`

- [ ] **Step 1: Viết fixture verification fail**

SQL test phải yêu cầu các scenario:

```sql
select test_assert((select count(*) from public.airports) >= 5, 'requires five airports');
select test_assert((select count(*) from public.flight_routes) >= 5, 'requires route edges');
select test_assert((select count(*) from public.flight_services) >= 6, 'requires schedule services');
```

Dataset gồm `SGN`, `SIN`, `BKK`, `LHR`, `CDG`; một direct `SGN→LHR`, một valid connection
`SGN→SIN→LHR`, một connection layover quá ngắn và một route inactive.

- [ ] **Step 2: Reset và quan sát RED**

```bash
supabase db reset --local --yes
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 -f supabase/snippets/test_route_discovery_fixture.sql
```

Expected: FAIL do fixture rows chưa tồn tại.

- [ ] **Step 3: Tạo fixture development-only**

Tạo `data_sources.code = 'route_discovery_fixture'`, `environment_scope = 'development'`, toàn bộ
production/SEO rights là false. Dùng UUID cố định và explicit column lists để fixture deterministic.

- [ ] **Step 4: Đăng ký seed file đúng thứ tự**

Trong `supabase/config.toml`:

```toml
sql_paths = ["./seed/fixture.sql", "./seed/flight_routing_fixture.sql"]
```

- [ ] **Step 5: Reset và chạy GREEN fixture test**

Expected: database reset sạch; counts và scenario identifiers đúng.

### Task 3: Route-options read model

**Files:**
- Create: `supabase/sql_src/schema/public/route_options.sql`
- Create: `supabase/sql_src/functions/route_discovery/calculate_layover_minutes.sql`
- Create: `supabase/sql_src/functions/route_discovery/refresh_route_options.sql`
- Modify: `supabase/functions/_shared/security/tests/route_discovery_sql_contract.test.ts`
- Create: `supabase/snippets/test_refresh_route_options.sql`
- Create: `supabase/migrations/<timestamp>_route_options.sql`

- [ ] **Step 1: Viết RED contract/behavior tests**

Contract yêu cầu one-table/one-function files, explicit `search_path`, invoker security và
service-role-only refresh. Behavior test yêu cầu:

```text
1 direct SGN→LHR option
1 valid SGN→SIN→LHR option
0 option từ inactive route
0 option có layover dưới 45 phút
```

- [ ] **Step 2: Chạy tests và xác nhận fail vì objects chưa tồn tại**

- [ ] **Step 3: Tạo `route_options`**

Fields:

```text
id, origin_airport_id, destination_airport_id, stop_count,
service_ids, connection_airport_ids, operating_airline_ids,
marketing_airline_ids, total_flight_minutes, layover_minutes,
total_duration_minutes, departure_local_time, arrival_local_time,
valid_from, valid_to, days_of_week, confidence_score,
data_version, generated_at
```

`stop_count` chỉ nhận `0` hoặc `1`; arrays có cardinality tương ứng; public RLS đóng với client.

- [ ] **Step 4: Tạo `calculate_layover_minutes`**

Helper nhận first-leg arrival time/day offset và second-leg departure time, trả số phút đến lần
departure hợp lệ tiếp theo trong cùng hoặc ngày kế tiếp. Chấp nhận `45..1440` phút ở refresh logic.

- [ ] **Step 5: Tạo `refresh_route_options`**

Flow SQL có comment `STEP 01..04`:

```text
STEP 01 lock/rebuild staging result
STEP 02 insert eligible direct services
STEP 03 join compatible one-stop service pairs
STEP 04 replace route_options and return counts/data version
```

Eligible statuses: `verified_active`, `likely_active`, `seasonal`. Validity windows/days phải giao
nhau; confidence option lấy minimum của các legs.

- [ ] **Step 6: Generate migration, reset, refresh và chạy GREEN behavior test**

Expected: đúng direct/one-stop counts, duration = flight minutes + layover, không duplicate options.

### Task 4: Search/filter/facets RPC

**Files:**
- Create: `supabase/sql_src/functions/route_discovery/rpc_search_routes.sql`
- Modify: `supabase/functions/_shared/security/tests/route_discovery_sql_contract.test.ts`
- Create: `supabase/snippets/test_rpc_search_routes.sql`
- Create: `supabase/migrations/<timestamp>_route_search.sql`

- [ ] **Step 1: Viết RED behavior tests cho public contract**

Input JSON contract:

```json
{
  "from": "SGN",
  "to": "LHR",
  "max_stops": 1,
  "airlines": ["SQ"],
  "exclude_airports": ["BKK"],
  "max_duration_minutes": 1200,
  "max_layover_minutes": 240,
  "departure_window": "morning",
  "limit": 20,
  "offset": 0
}
```

Test invalid IATA, same origin/destination, invalid limits, no-result, direct-only, airline filter,
connection exclusion, duration filter, deterministic order và facets.

- [ ] **Step 2: Chạy RED tests**

Expected: FAIL vì `public.rpc_search_routes(jsonb)` chưa tồn tại.

- [ ] **Step 3: Implement RPC**

RPC dùng `security invoker`, `set search_path = ''`, validate bounded input và trả envelope:

```json
{
  "status": "success",
  "data": { "options": [], "facets": {}, "pagination": {} },
  "error": null,
  "message_code": "ROUTE_SEARCH_COMPLETED"
}
```

Error codes gồm `ERR_ROUTE_SEARCH_INPUT_INVALID`, `ERR_AIRPORT_NOT_FOUND`,
`ERR_ROUTE_SEARCH_SAME_AIRPORT`. Chỉ grant execute cho `service_role` trong phase này.

- [ ] **Step 4: Ranking ổn định**

Order:

```sql
order by
  stop_count asc,
  total_duration_minutes asc,
  confidence_score desc,
  id asc
```

- [ ] **Step 5: Generate migration, reset/refresh và chạy GREEN tests**

Expected: mọi filter/facet assertion pass; SQL lint/advisors không có error.

### Task 5: Edge route-discovery query boundary

**Files:**
- Create: `supabase/functions/v1/route-discovery/query/request.ts`
- Create: `supabase/functions/v1/route-discovery/query/service.ts`
- Create: `supabase/functions/v1/route-discovery/query/handler.ts`
- Create: `supabase/functions/v1/route-discovery/query/index.ts`
- Create: `supabase/functions/v1/route-discovery/query/tests/request.test.ts`
- Create: `supabase/functions/v1/route-discovery/query/tests/handler.test.ts`
- Modify: `supabase/config.toml`

- [ ] **Step 1: Viết RED request parser tests**

Test normalization `sgn → SGN`, bounded arrays/pagination và reject unknown fields hoặc malformed
IATA values.

- [ ] **Step 2: Chạy RED Deno tests**

Expected: FAIL do parser/handler chưa tồn tại.

- [ ] **Step 3: Implement parser và service adapter**

Parser trả typed input; service chỉ gọi `public.rpc_search_routes` qua existing shared Supabase
client. Không chứa SQL filter/ranking logic.

- [ ] **Step 4: Implement handler/index**

Flow:

```text
OPTIONS/CORS → method check → parse → call service → normalize envelope → structured log → response
```

Response route-discovery cache metadata dùng `data_version`; unexpected errors trả `ERR_INTERNAL`
không lộ raw database error.

- [ ] **Step 5: Đăng ký function**

Trong `config.toml`, thêm `functions.route-discovery-query` trỏ đúng entrypoint và giữ JWT policy
phù hợp public read endpoint cùng rate limiting backend-owned.

- [ ] **Step 6: Chạy GREEN Edge tests/checks**

```bash
deno fmt --config supabase/functions/deno.json --check supabase/functions
deno lint --config supabase/functions/deno.json supabase/functions/v1/route-discovery
deno check --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query/index.ts
deno test --config supabase/functions/deno.json --allow-env --allow-read \
  supabase/functions/v1/route-discovery/query/tests
```

Expected: PASS không warning.

### Task 6: Documentation và full verification

**Files:**
- Modify: `docs/features/flight-routing/README.md`
- Create: `docs/features/route-discovery/README.md`
- Create: `supabase/snippets/e2e_route_discovery.sql`

- [ ] **Step 1: Document source/read-model/API boundaries**

Ghi rõ `flight_routes` vs `flight_services` vs `route_options`, supported filters, error codes,
fixture scenarios và exact local commands.

- [ ] **Step 2: Chạy full database rebuild**

```bash
supabase db reset --local --yes
```

Expected: mọi migration và seed apply sạch.

- [ ] **Step 3: Chạy end-to-end SQL**

Refresh options, search `SGN→LHR` direct/one-stop, filter airline, exclude connection và xác nhận
facets/pagination.

- [ ] **Step 4: Chạy quality gates**

```bash
supabase db lint --local --schema admin,public --fail-on error
supabase db advisors --local --type security --fail-on error
supabase db advisors --local --type performance --fail-on error
deno fmt --config supabase/functions/deno.json --check supabase/functions
deno test --config supabase/functions/deno.json --allow-all supabase/functions
git diff --check
```

Expected: tất cả exit 0, không test failure hoặc advisor error.

- [ ] **Step 5: Review phạm vi và handoff**

Xác nhận không có live pricing, pSEO read models, real provider integration, Redis hoặc generic
multimodal graph trong diff. Không commit; báo verification evidence và hỏi user trước mọi commit.
