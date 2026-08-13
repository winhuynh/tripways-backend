import { getServiceRoleClient } from '@shared/supabase.ts';
import type { RateLimitDecision } from '@shared/rate_limit.ts';
import { createTravelpayoutsAdapter } from '../../ingestion/price-estimates/providers/travelpayouts-provider.ts';
import { handleRouteCacheRequest } from './handler.ts';
import type { RouteCacheRequest } from './request.ts';
import { executeRouteCache } from './service.ts';

const client = getServiceRoleClient();
const adapter = createTravelpayoutsAdapter({
  token: requiredEnv('TRAVELPAYOUTS_TOKEN'),
  maxRecords: boundedIntegerEnv('TRAVELPAYOUTS_MAX_ROUTES_PER_ORIGIN', 100, 1, 1000),
  timeoutMs: boundedIntegerEnv('TRAVELPAYOUTS_TIMEOUT_MS', 5000, 1000, 10000),
});

Deno.serve((request) =>
  handleRouteCacheRequest(request, {
    workerSecret: requiredEnv('INGESTION_WORKER_SECRET'),
    consume: consumeRateLimit,
    execute: (input, allowRefresh) =>
      executeRouteCache(input, {
        read: readCache,
        claim: claimRefresh,
        load: (scope) =>
          adapter.load({
            origin: scope.origin,
            destination: scope.destination,
            currencyCode: scope.currency,
            marketCode: scope.market,
            locale: scope.locale,
          }),
        publish: publishScope,
        fail: failRefresh,
      }, allowRefresh),
  })
);

async function readCache(input: RouteCacheRequest) {
  const { data, error } = await client.rpc('rpc_get_flight_route_cache', { p_input: input });
  if (error || !isEnvelope(data)) throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
  return data;
}

async function claimRefresh(input: RouteCacheRequest) {
  const { data, error } = await client.rpc('rpc_claim_flight_route_cache_refresh', {
    p_input: input,
  });
  if (error || !isClaim(data)) throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
  return data;
}

async function publishScope(
  leaseToken: string,
  observations: unknown[],
  input: RouteCacheRequest,
) {
  const { data, error } = await client.rpc('rpc_publish_flight_route_cache_scope', {
    p_lease_token: leaseToken,
    p_source_code: 'travelpayouts',
    p_origin_iata: input.origin,
    p_destination_iata: input.destination,
    p_market_code: input.market,
    p_currency_code: input.currency,
    p_locale: input.locale,
    p_observations: observations,
    p_publication_source_type: publicationSourceType(),
  });
  if (error || !isEnvelope(data)) throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
  return data;
}

async function failRefresh(leaseToken: string, code: string): Promise<void> {
  await client.rpc('rpc_fail_flight_route_cache_refresh', {
    p_lease_token: leaseToken,
    p_failure_code: /^ERR_[A-Z0-9_]+$/.test(code) ? code : 'ERR_PROVIDER_UNAVAILABLE',
  });
}

async function consumeRateLimit(subjectHash: string): Promise<RateLimitDecision> {
  const { data, error } = await client.rpc('consume_auth_command_attempt', {
    p_subject_hash: subjectHash,
    p_action: 'flight_route_cache_refresh',
  });
  if (error || !isRateLimitDecision(data)) throw new Error('ERR_RATE_LIMITED');
  return { allowed: data.allowed, remaining: data.remaining, resetAt: data.reset_at };
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error('ERR_SERVER_CONFIGURATION');
  return value;
}

function boundedIntegerEnv(
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const raw = Deno.env.get(name)?.trim();
  const value = raw ? Number(raw) : fallback;
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error('ERR_SERVER_CONFIGURATION');
  }
  return value;
}

function publicationSourceType(): 'development_fixture' | 'staging' | 'production' {
  const value = requiredEnv('PUBLICATION_SOURCE_TYPE');
  if (value !== 'development_fixture' && value !== 'staging' && value !== 'production') {
    throw new Error('ERR_SERVER_CONFIGURATION');
  }
  return value;
}

function isEnvelope(value: unknown): value is {
  data: { status: string; routes: unknown[] };
  meta: Record<string, unknown>;
  error: null;
} {
  if (!isRecord(value) || !isRecord(value.data) || !isRecord(value.meta)) return false;
  return typeof value.data.status === 'string' && Array.isArray(value.data.routes) &&
    value.error === null;
}

function isClaim(value: unknown): value is
  | { action: 'refresh'; leaseToken: string }
  | { action: 'wait' | 'cooldown' } {
  if (!isRecord(value)) return false;
  if (value.action === 'refresh') return typeof value.leaseToken === 'string';
  return value.action === 'wait' || value.action === 'cooldown';
}

function isRateLimitDecision(value: unknown): value is {
  allowed: boolean;
  remaining: number;
  reset_at: string;
} {
  return isRecord(value) && typeof value.allowed === 'boolean' &&
    typeof value.remaining === 'number' && typeof value.reset_at === 'string';
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
