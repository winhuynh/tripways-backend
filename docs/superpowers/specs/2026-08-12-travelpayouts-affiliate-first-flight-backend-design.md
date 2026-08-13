# Travelpayouts Affiliate-First Flight Backend Design

**Date:** 2026-08-12  
**Status:** Approved direction, pending written-spec review  
**Initial commercial provider:** Travelpayouts / Aviasales Data API  
**Scope:** `tripways-backend`

## 1. Product Objective

Tripways is a travel-content and flight-discovery product. Its indexable pages help a user discover
routes, destinations, and recently observed fare signals, then continue to an approved affiliate
search or booking destination. Tripways does not operate a public aviation-data API, resell a
schedule database, or retain provider search results as a long-lived dataset.

The backend therefore separates:

1. stable place/reference data;
2. short-lived content observations suitable for pSEO;
3. user-initiated commercial search and affiliate handoff.

## 2. Provider Roles

### 2.1 OurAirports

OurAirports remains the approved source for airport and geographic reference data under the
existing ingestion pipeline. It does not establish fare, availability, popularity, or recurring
commercial schedule truth.

### 2.2 Aviasales Data API

Aviasales Data API is the initial source for short-lived content observations:

- popular destinations and routes;
- recently observed cheapest fares;
- direct/non-direct indication when explicitly returned;
- departure/return dates;
- duration and transfer count when explicitly returned;
- market, locale, and currency context;
- provider result/deep-link code when permitted;
- `found_at` and `expires_at` when returned.

These records are cached observations from Aviasales search history. They are not live offers,
availability guarantees, authoritative schedules, or evidence that a route operates every day or
season.

### 2.3 Travelpayouts Affiliate Tools

Approved links, widgets, or White Label provide the initial commercial handoff. The backend owns
partner configuration, attribution identifiers, SubID construction, allowlisting, disclosure, and
click analytics. The browser never supplies an arbitrary redirect target.

### 2.4 Live Search Providers

Aviasales Search API and Kiwi are future adapters. They remain disabled until Tripways satisfies
provider traffic and approval requirements. Live search is always initiated by an explicit user
action, stored only for the permitted short period, and excluded from pSEO and crawler access.

### 2.5 Schedule Enrichment

AeroDataBox, AirLabs, and other schedule providers are removed from the current implementation
scope. A schedule-enrichment boundary may be designed later only when measured user demand requires
operating weekdays, flight numbers, or timetable details that the commercial content provider does
not supply.

## 3. Non-Goals

- No AeroDataBox or AirLabs adapter, credential, cron, schema, fixture, or production call.
- No long-lived provider route or schedule archive.
- No provider response history or derived seasonality database.
- No automatic generation of live searches for bots, cron jobs, or page rendering.
- No indexable search-result pages.
- No merging of live results from providers whose terms prohibit aggregation.
- No booking, payment, ticket issuance, refund, or customer-support responsibility.
- No unofficial Google Flights scraper or RapidAPI proxy published by an unaffiliated third party.
- No public bulk export capable of reconstructing provider data.

## 4. Target Architecture

```text
OurAirports ingestion
  -> canonical countries / cities / airports

Daily content-observation cron
  -> Travelpayouts Data adapter
    -> validate provider rights and request scope
      -> normalize short-lived observations
        -> atomic current-observation replacement
          -> rebuild affected pSEO read models
            -> CDN revalidation/version switch

Indexable content page
  -> current pSEO read model
    -> route/destination discovery + observed-fare disclosure
      -> signed affiliate handoff or search form

Explicit user search
  -> approved White Label initially
    -> future approved live-search adapter
      -> noindex result surface
        -> allowlisted affiliate redirect
```

PostgreSQL owns rights, observation validity, publication, indexability, affiliate-target
allowlisting, and atomic replacement. Edge Functions own provider transport, credentials, parsing,
and normalized error handling. Public transports remain bounded and provider-neutral.

## 5. Content Observation Model

The existing `route_price_estimates` boundary is retained only if it can accurately represent an
observed cached fare. Names and contracts that imply an estimated range without evidence must be
revised. The canonical content observation includes:

- source and provider record identity;
- origin and destination city/airport identity when known;
- trip type;
- direct flag or transfer count when explicitly returned;
- observed amount and currency;
- market and locale;
- departure and optional return date;
- observed/found timestamp;
- provider expiry timestamp;
- Tripways cache expiry;
- affiliate/deep-link reference, never a browser-controlled URL;
- publication status and provenance.

Missing price is a distinct state and never becomes zero. A single observed fare is not converted
into an invented price range. The public contract describes it as a recently observed or cached
fare, not a live or bookable offer.

## 6. Freshness and Replacement

The content cron runs daily. The initial maximum Tripways cache duration is 24 hours, further
bounded by the provider `expires_at` value when it is earlier.

For each configured scope:

1. Resolve the approved active source and rights.
2. Skip a request while the current observation is still within its refresh window unless an
   operator requests a privileged refresh.
3. Fetch only bounded origin/market/locale/currency scopes.
4. Validate and normalize the response without logging its body.
5. Publish the new current observation set atomically.
6. Rebuild only affected pSEO read models.
7. Replace and delete the previous provider-derived observation set.
8. Revalidate affected cached pages.

At read time, an expired observation is omitted independently of cron health. A failed refresh does
not make a route disappear and does not deindex an otherwise useful editorial/reference page; only
the stale commercial module is removed. Pages whose only qualifying content is provider-derived
must fail the normal page-depth/indexability gate.

## 7. Provider-Neutral Boundaries

Content providers implement an internal adapter contract:

```ts
interface FlightContentProvider {
  fetch(request: FlightContentRequest): Promise<ProviderContentResult>;
  normalize(result: ProviderContentResult): FlightContentBatch;
}
```

Future live-search providers implement a separate contract because user-triggered offers have
different rights, expiry, storage, and SEO rules:

```ts
interface LiveFlightSearchProvider {
  start(request: LiveSearchRequest): Promise<LiveSearchSession>;
  poll(session: LiveSearchSession): Promise<LiveSearchResult>;
  resolveHandoff(selection: LiveOfferSelection): Promise<AffiliateHandoff>;
}
```

Content observations and live offers are never interchangeable. Switching provider is a
privileged configuration change after adapter tests, rights review, and private validation. Public
page contracts do not expose provider field names.

## 8. Affiliate Handoff

The initial handoff uses an approved Travelpayouts/Aviasales URL pattern, widget, or White Label
configuration. The backend:

- resolves partner and campaign configuration server-side;
- permits only reviewed HTTPS hosts and path patterns;
- constructs bounded SubIDs from internal page/route/placement identifiers;
- signs or stores an opaque, short-lived handoff reference;
- records disclosure-safe click events;
- rejects tampering, expiry, inactive programs, and unknown targets;
- never accepts a destination URL directly from the public browser.

Each CTA states that the displayed price was observed previously and will be rechecked on the
partner site. Affiliate disclosure is present before production enablement.

## 9. SEO Boundary

Indexable pages may contain editorial/reference content and valid Data API observations because
Aviasales documents the Data API as suitable for content/static pages.

Live search is different:

- every request requires an explicit user action;
- search results are returned in full as required by the provider;
- booking links are created only at the allowed interaction point;
- result routes are blocked from crawlers and return `noindex`;
- results do not create or enrich pSEO inventory;
- the backend does not prefetch, scrape, aggregate, or archive live results.

## 10. Data Retention

Tripways keeps only the current content-observation publication needed by active pages. It does not
retain raw Travelpayouts responses, previous provider observation sets, or production-derived
fixtures. Operational evidence may retain source identity, counts, hashes, timing, quota metadata,
and stable error codes without provider content.

Temporary ingestion data is purged after publication and by bounded failure cleanup. Debug and
analytics logs exclude API tokens, raw responses, full affiliate URLs, and arbitrary provider
metadata. Backup retention must be represented in the rights register and reviewed before remote
production data is enabled.

## 11. Failure Behavior

- Provider timeout, quota exhaustion, authorization failure, malformed response, and empty valid
  response use different stable error codes.
- Failed content refresh leaves editorial/reference pages available.
- Expired commercial observations disappear from page payloads automatically.
- Provider failure never becomes evidence that a route does not exist.
- Affiliate kill switch removes or disables commercial CTAs without breaking page discovery.
- Live-search failure returns an unavailable/retry response and never falls back to stale pSEO data
  as if it were live.
- No provider switch occurs automatically; operators decide per case.

## 12. Repository Realignment

Implementation reviews all backend flight-related contracts and aligns them to the new boundary:

- remove the AeroDataBox schedule-ingestion spec;
- update roadmap, P2/P3, City Hub, and feature documentation that assumes AirLabs or a licensed
  recurring-schedule database is required before affiliate content;
- retain generic route tables only where they serve provider-neutral discovery and existing local
  fixtures, not as a promise to archive an aviation provider database;
- revise price schemas, read models, RPCs, ingestion functions, fixtures, and tests so observed
  cached fares are represented truthfully;
- implement Travelpayouts content ingestion and daily cron;
- implement affiliate partner/target/handoff boundaries needed for Aviasales;
- keep live-search endpoints disabled or explicitly unsupported until an approved provider exists;
- update public disclaimers, provenance, freshness, and indexability rules;
- regenerate deterministic migrations from `supabase/sql_src` rather than editing generated files
  directly.

Unrelated homepage and pSEO changes already present in the worktree must be preserved and integrated
carefully rather than reverted.

## 13. Security

- Travelpayouts tokens remain server-side in Supabase secrets.
- Cron invokes a fixed Edge Function with the existing privileged worker authentication boundary.
- Exposed tables use RLS and least-privilege grants; raw/operational data remains admin.
- Privileged functions set an explicit empty `search_path` and schema-qualify references.
- Provider and affiliate errors are normalized before public responses.
- Redirect hosts and paths are allowlisted and tested against open redirects.
- SubIDs contain bounded internal identifiers and no personal data.
- Analytics excludes passenger identity, payment data, provider payloads, and full IP addresses.

## 14. Testing and Verification

Test-first implementation covers:

- Travelpayouts request construction and sanitized synthetic response parsing;
- cached-fare semantics, currency, market, dates, and provider expiry;
- missing versus zero price;
- direct versus unknown route evidence;
- daily refresh eligibility and read-time expiry;
- atomic replacement and cleanup;
- provider rights and source switching;
- page payloads with available, missing, and expired observations;
- unchanged editorial page availability after provider failure;
- affiliate allowlisting, signing, SubID bounds, tampering, and kill switch;
- public disclosure and provenance;
- live-search noindex and user-initiation guards;
- RLS, grants, secret isolation, and absence of raw provider logging;
- compatibility with existing route/page contracts where retained.

Completion requires format checks, TypeScript/Deno checks and tests, SQL contract and E2E tests,
migration regeneration, a clean local Supabase rebuild, database/security verification, and a
private remote smoke test after the user supplies credentials and approves remote configuration.

## 15. Rollout

1. Realign documentation and canonical contracts around content observations and affiliate handoff.
2. Implement and verify the Travelpayouts Data adapter with synthetic fixtures.
3. Implement current-observation publication, 24-hour expiry, and daily cron configuration.
4. Update pSEO read models, disclaimers, and provider-failure behavior.
5. Implement safe Travelpayouts affiliate handoff and click tracking.
6. Run the full local verification suite.
7. Register Tripways with Travelpayouts and connect Aviasales.
8. Add the real token to remote secrets only with user approval.
9. Run private/noindex remote validation.
10. Enable production affiliate content and indexability separately after review.

Remote credential changes, cron installation, production publication, and production indexability
remain approval-gated operations.
