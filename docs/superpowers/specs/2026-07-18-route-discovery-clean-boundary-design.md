# Route Discovery Clean Boundary Design

## Goal

Refactor the Tripways Route Discovery backend into a small, explicit Supabase boundary that is easy
to trace and maintain. PostgreSQL remains the owner of route eligibility, graph construction,
ranking, facets, and pagination. Edge Functions remain thin HTTP transports and do not recreate a
mobile-style use-case or repository stack.

This is an intentional breaking contract. The Tripways web consumer will be migrated in the same
development cycle and compatibility with the prototype REST RPC call is not required.

## Scope

This phase includes:

- a stable versioned Edge request and response contract for route search;
- strict request parsing and normalization;
- a thin route-discovery handler;
- safe mapping from the internal RPC envelope to the public Edge envelope;
- stable HTTP and application error mapping;
- focused shared helpers only where they remove duplicated boundary risk;
- contract, request, handler, SQL, and end-to-end local verification;
- removal of web reliance on direct PostgREST RPC access and the service-role key.

This phase does not add live fares, booking, authentication requirements, cache infrastructure,
new route-ranking rules, or an external travel provider.

## Architectural Decision

The backend flow is:

```text
HTTP request
→ request DTO parser
→ Edge handler
→ PostgreSQL RPC
→ response contract mapper
→ stable HTTP response
```

There is no backend `usecases` directory. For stored Route Discovery, the PostgreSQL RPC is the
application/domain operation. Adding `UseCase → Repository → Provider → RPC` would create
pass-through layers without moving ownership or improving substitution.

A backend service or provider adapter is introduced only when orchestration exists outside
PostgreSQL, such as calling multiple airline/GDS providers, enforcing provider idempotency,
normalizing external payloads, or coordinating multiple commands.

## Target File Structure

```text
supabase/
├── functions/
│   ├── _shared/
│   │   ├── edge.ts
│   │   ├── rate_limit.ts
│   │   ├── supabase.ts
│   │   └── security/
│   └── v1/
│       └── route-discovery/
│           └── query/
│               ├── index.ts
│               ├── request.ts
│               ├── response.ts
│               ├── handler.ts
│               └── tests/
├── sql_src/
│   └── functions/
│       └── route_discovery/
├── migrations/
└── seed/
```

`index.ts` creates runtime dependencies and delegates to the handler. `request.ts` validates
unknown HTTP input. `handler.ts` owns only transport orchestration. `response.ts` validates/maps the
internal RPC result and creates the stable public envelope.

## Public Request Contract

The Edge endpoint accepts:

```json
{
  "action": "search_routes",
  "input": {
    "from": "SGN",
    "to": "SIN",
    "max_stops": 1,
    "airlines": [],
    "limit": 20,
    "offset": 0
  }
}
```

Rules:

- `action` must equal `search_routes`;
- `from` and `to` are required three-letter IATA strings and are normalized to uppercase;
- origin and destination must differ;
- `max_stops` is optional and constrained to the route-discovery capability;
- `airlines` is an optional unique list of normalized airline codes;
- pagination is bounded and receives explicit defaults;
- unknown fields do not reach the RPC;
- malformed input fails before database access.

The validated request type is an Edge boundary DTO. It is not reused as a database row type.

## Public Response Contract

Successful requests return:

```json
{
  "status": "success",
  "data": {
    "routes": [],
    "pagination": {
      "total": 0,
      "limit": 20,
      "offset": 0
    },
    "facets": {
      "stops": [],
      "airlines": []
    }
  },
  "error": null
}
```

Errors return:

```json
{
  "status": "error",
  "data": null,
  "error": {
    "code": "ROUTE_DISCOVERY_INVALID_REQUEST",
    "message": "The route search request is invalid."
  }
}
```

The public contract never exposes SQL error text, stack traces, service-role details, RPC names, or
raw provider payloads.

## HTTP Semantics

- `200`: valid request, including an empty route result;
- `400`: invalid request DTO;
- `401` or `403`: authentication/authorization failure if the endpoint policy requires it;
- `429`: rate limit;
- `500`: unexpected internal contract failure;
- `503`: Route Discovery database/provider unavailable.

Errors have stable public codes. Internal errors remain available only to server-side observability.

## PostgreSQL Boundary

PostgreSQL continues to own:

- direct and one-stop route construction;
- route eligibility and source-trust constraints;
- ranking and confidence;
- facets and pagination;
- development fixture isolation.

The RPC may be revised as a breaking internal contract when needed to make its input and result
unambiguous. SQL source remains canonical under `supabase/sql_src`; generated migrations must be
regenerated through the repository script and verified from a local reset.

No production rule is moved from SQL into the Edge handler.

## Security

- Service-role access remains in the Edge/server boundary only.
- The browser never receives a service-role or secret key.
- Every exposed table retains RLS and least-privilege grants.
- Privileged functions use an explicit `search_path`.
- Raw provider data remains outside exposed schemas.
- Development fixtures remain non-production and non-indexable.

## Testing

Tests are organized by boundary:

- request parser tests cover normalization, defaults, invalid action, invalid IATA, same-airport
  input, airline normalization, and pagination bounds;
- response mapper tests reject malformed internal RPC envelopes and preserve stable public shapes;
- handler tests verify one RPC call with validated input and correct HTTP/error mapping;
- SQL contract tests protect function security, grants, and stable internal result requirements;
- local end-to-end checks call the Edge endpoint against a database rebuilt from migrations/seed.

Implementation follows test-first development. Each behavior test must be observed failing for the
intended reason before production behavior is changed.

## Migration Order

1. Lock the new request/response contract in tests.
2. Implement request parsing and response mapping.
3. Refactor the handler and composition root.
4. Revise SQL/RPC only where the new internal boundary requires it.
5. Regenerate and reset the local database when SQL changes.
6. Verify the Edge endpoint locally.
7. Migrate the Tripways web provider.
8. Remove direct web PostgREST/service-role access.

The backend and web are considered complete only when the new end-to-end path passes.

## Explicit Non-Goals

- No generic base handler, base repository, use-case superclass, DI container, or provider factory.
- No external provider interface until an external provider is integrated.
- No cache registry or cache envelope without a measured product requirement.
- No compatibility adapter for the prototype direct RPC consumer.
