# Route Discovery Clean Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the prototype Route Discovery Edge transport with a strict breaking request/response contract while keeping PostgreSQL/RPC as the domain operation.

**Architecture:** `index.ts` is the composition root, `request.ts` parses unknown HTTP input, `handler.ts` performs thin orchestration, and `response.ts` validates/maps the internal RPC envelope into a stable public envelope. No backend use-case, repository, or provider layer is added for the single stored-route RPC.

**Tech Stack:** Supabase Edge Functions, Deno, strict TypeScript, PostgreSQL RPC, Deno tests.

---

## File Map

- Modify `supabase/functions/v1/route-discovery/query/request.ts`: typed action/input parser.
- Create `supabase/functions/v1/route-discovery/query/response.ts`: internal RPC validation and public response mapping.
- Modify `supabase/functions/v1/route-discovery/query/handler.ts`: transport-only orchestration.
- Modify `supabase/functions/v1/route-discovery/query/index.ts`: RPC dependency composition and structured logging.
- Modify `supabase/functions/_shared/edge.ts`: register only stable public error codes/statuses needed by the new contract.
- Modify route-discovery tests to lock the breaking contract.
- Modify `docs/features/route-discovery/README.md`: document the new public Edge contract.

### Task 1: Strict breaking request DTO

**Files:**

- Modify: `supabase/functions/v1/route-discovery/query/tests/request.test.ts`
- Modify: `supabase/functions/v1/route-discovery/query/request.ts`

- [ ] **Step 1: Write failing request contract tests**

Add tests proving the parser accepts `{ action: "search_routes", input }`, uppercases IATA and
airline values, deduplicates airlines, supplies `limit: 20` and `offset: 0`, and rejects an unknown
action, same airport, invalid IATA, non-integer bounds, and unknown fields.

```ts
assert.deepEqual(
  parseRouteSearchRequest({
    action: "search_routes",
    input: { from: "sgn", to: "sin", airlines: ["sq", "SQ"] },
  }),
  {
    action: "search_routes",
    input: { from: "SGN", to: "SIN", airlines: ["SQ"], limit: 20, offset: 0 },
  },
);
```

- [ ] **Step 2: Run and verify RED**

Run:

```bash
deno test --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query/tests/request.test.ts
```

Expected: FAIL because the current parser expects the old flat request and does not normalize.

- [ ] **Step 3: Implement the typed parser**

Export `RouteSearchRequest`, `RouteSearchInput`, and `parseRouteSearchRequest`. Whitelist supported
fields, normalize codes, enforce `from !== to`, constrain `max_stops` to `0 | 1`, require positive
bounded `limit <= 100`, require non-negative `offset`, and throw
`ERR_ROUTE_DISCOVERY_INVALID_REQUEST` for every public validation failure.

- [ ] **Step 4: Run and verify GREEN**

Run the Task 1 command. Expected: all request tests pass.

### Task 2: Stable response mapper

**Files:**

- Create: `supabase/functions/v1/route-discovery/query/tests/response.test.ts`
- Create: `supabase/functions/v1/route-discovery/query/response.ts`

- [ ] **Step 1: Write failing response tests**

Define a valid internal RPC fixture with `data`, `meta`, and `error`. Assert mapping to:

```ts
{
  status: 'success',
  data: {
    routes: fixture.data,
    pagination: { total: 1, limit: 20, offset: 0 },
    facets: fixture.meta.facets,
  },
  error: null,
}
```

Add rejection cases for missing arrays, malformed pagination/facets, malformed routes, and non-null
internal RPC error. Contract failures must throw `ERR_ROUTE_DISCOVERY_CONTRACT`.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
deno test --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query/tests/response.test.ts
```

Expected: FAIL because `response.ts` does not exist.

- [ ] **Step 3: Implement strict internal validation and public mapping**

Keep raw input as `unknown`, use focused record/array/type guards, return a typed
`RouteDiscoverySuccessResponse`, and never cast the complete unknown envelope without validation.

- [ ] **Step 4: Run and verify GREEN**

Run the Task 2 command. Expected: all response tests pass.

### Task 3: Thin handler and stable HTTP errors

**Files:**

- Modify: `supabase/functions/v1/route-discovery/query/tests/handler.test.ts`
- Modify: `supabase/functions/v1/route-discovery/query/handler.ts`
- Modify: `supabase/functions/_shared/edge.ts`

- [ ] **Step 1: Replace handler tests with the breaking contract**

Assert POST parsing, one dependency call with normalized input, the public success envelope, `400`
for `ERR_ROUTE_DISCOVERY_INVALID_REQUEST`, `503` for
`ERR_ROUTE_DISCOVERY_UNAVAILABLE`, `500` for `ERR_ROUTE_DISCOVERY_CONTRACT`, and existing `405` /
malformed JSON behavior.

- [ ] **Step 2: Run and verify RED**

Run:

```bash
deno test --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query/tests/handler.test.ts
```

Expected: FAIL because the old handler forwards the old flat envelope.

- [ ] **Step 3: Implement transport-only orchestration**

The handler parses the request, calls `dependencies.searchRoutes(validated.input)`, maps the result
through `mapRouteSearchResponse`, and returns JSON. It catches only at the HTTP boundary. Register
the three stable Route Discovery codes in `_shared/edge.ts`.

- [ ] **Step 4: Run and verify GREEN**

Run the Task 3 command. Expected: all handler tests pass.

### Task 4: Composition root and documentation

**Files:**

- Modify: `supabase/functions/v1/route-discovery/query/index.ts`
- Modify: `docs/features/route-discovery/README.md`

- [ ] **Step 1: Update the composition root**

Keep the service-role client inside `index.ts`, call `rpc_search_routes({ p_input: input })`, convert
Supabase errors to `ERR_ROUTE_DISCOVERY_UNAVAILABLE`, pass `result.data` as unknown to the handler,
and emit the existing structured request log without secrets or payloads.

- [ ] **Step 2: Update the feature documentation**

Document the action-wrapped request, success/error envelopes, HTTP statuses, and the fact that the
Edge transport delegates business rules to PostgreSQL.

- [ ] **Step 3: Run route boundary verification**

Run:

```bash
deno fmt --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query
deno lint --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query
deno check --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query/index.ts
deno test --config supabase/functions/deno.json \
  supabase/functions/v1/route-discovery/query/tests
```

Expected: format completes and lint/check/tests exit 0.

### Task 5: Backend regression and local endpoint verification

**Files:**

- Modify only if a scoped verification defect is found.

- [ ] **Step 1: Run repository verification**

Run:

```bash
pnpm format:check
pnpm edge:fmt:check
pnpm edge:check
pnpm test:auth
deno test --config supabase/functions/deno.json \
  supabase/functions/_shared/tests \
  supabase/functions/v1/route-discovery/query/tests
```

Expected: every command exits 0.

- [ ] **Step 2: Verify local Edge contract**

Serve the Route Discovery function against the running local Supabase stack and POST the documented
SGN→SIN request. Expected: HTTP 200 with `status: "success"`, `data.routes`, pagination, facets, and
`error: null`.

- [ ] **Step 3: Preserve repository state**

Do not commit, push, deploy, or regenerate SQL migrations unless implementation proves an RPC/SQL
change is required. If SQL remains unchanged, explicitly report that database reset was skipped
because the refactor changed only the Edge contract.
