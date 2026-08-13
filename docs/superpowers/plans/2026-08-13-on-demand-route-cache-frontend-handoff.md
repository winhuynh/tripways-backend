# On-demand Route Cache Frontend Handoff Plan

**Status:** Backend handoff; frontend implementation intentionally deferred  
**Backend endpoint:** `POST /functions/v1/flight-route-cache`

## Goal

Render City and Route pSEO pages immediately from their server read model. When
`flight_data_state` is `loading`, render an accessible route-list skeleton and let a browser request
the on-demand cache endpoint. Never put the Travelpayouts token or Supabase service-role key in the
frontend.

## Future file boundaries

- `src/features/flights/route-cache/contract.ts`: request/response runtime schema and DTO types.
- `src/features/flights/route-cache/client.ts`: one abortable POST transport.
- `src/features/flights/route-cache/use-route-cache.ts`: deduplicated client request state.
- `src/features/flights/components/route-list.tsx`: available route cards.
- `src/features/flights/components/route-list-skeleton.tsx`: fixed-size accessible placeholder.
- `src/features/flights/components/route-list-empty.tsx`: cooldown/empty copy and affiliate CTA.
- City and Route page components: mount the hook only for `loading`.

## Render contract

- `available`: render server-provided routes immediately; perform zero client requests.
- `loading`: render the skeleton in initial HTML, then issue one browser request after hydration.
- `unavailable`: render neutral copy and “Check latest flights” CTA; do not retry automatically.
- Timeout/error: replace the skeleton with the same neutral CTA. The base page remains usable.

## Client request

Send only canonical public codes already supplied by the server page payload:

```json
{
  "origin": "BKK",
  "destination": "LON",
  "currency": "USD",
  "market": "us",
  "locale": "en-GB"
}
```

City Page omits `destination`. Route Page includes it. Cancel on navigation or identity change with
`AbortController`. Deduplicate identical in-flight cache keys. Do not retry HTTP 429/503
automatically; the backend owns cooldown and day-six refresh.

## Accessibility and price wording

- Reserve final-list height to avoid layout shift.
- Use `aria-busy="true"`; mark visual skeleton blocks `aria-hidden="true"`.
- Disable shimmer under `prefers-reduced-motion: reduce`.
- Do not move keyboard focus when results replace the skeleton.
- Label cached amounts “Estimated price” or “Recently observed price”.
- Keep the backend disclosure visible and use only server-owned affiliate handoff URLs.

## Analytics

Track request/result/duration using public origin/destination codes only. Do not send observation
references, affiliate paths, IP addresses, tokens, or raw responses. Analytics never authorizes a
provider refresh.

## Tests and acceptance

- Cache hit renders routes and performs zero requests.
- Cache miss renders skeleton before hydration and one request afterward.
- Duplicate mounts share a request; navigation aborts the old request.
- Empty, cooldown, timeout, 429, and 503 collapse to neutral copy.
- Disclosure, CTA, accessibility, and reduced-motion checks pass.
- Production bundles contain no Travelpayouts token or Supabase service-role key.

Frontend completion means a cold page renders useful reference content immediately, fills its route
section without navigation, and provider failure affects only that section.
