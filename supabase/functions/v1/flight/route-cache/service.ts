import type { RouteCacheRequest } from './request.ts';

type RouteCacheEnvelope = {
  data: { status: string; routes: unknown[] };
  meta: Record<string, unknown>;
  error: null;
};

type ClaimResult =
  | { action: 'refresh'; leaseToken: string }
  | { action: 'wait' | 'cooldown'; leaseToken?: never; response?: RouteCacheEnvelope };

type LoadResult =
  | { ok: true; batch: { observations: unknown[] } }
  | { ok: false; issues: Array<{ code: string }> };

export type RouteCacheDependencies = {
  read(input: RouteCacheRequest): Promise<RouteCacheEnvelope>;
  claim(input: RouteCacheRequest): Promise<ClaimResult>;
  load(input: RouteCacheRequest): Promise<LoadResult>;
  publish(
    leaseToken: string,
    observations: unknown[],
    input: RouteCacheRequest,
  ): Promise<RouteCacheEnvelope>;
  fail(leaseToken: string, code: string): Promise<void>;
};

export async function executeRouteCache(
  input: RouteCacheRequest,
  dependencies: RouteCacheDependencies,
  allowRefresh = true,
): Promise<RouteCacheEnvelope> {
  const cached = await dependencies.read(input);
  if (cached.data.status === 'available') return cached;
  if (!allowRefresh) return cached;

  const claim = await dependencies.claim(input);
  if (claim.action !== 'refresh') return claim.response ?? cached;

  let loaded: LoadResult;
  try {
    loaded = await dependencies.load(input);
  } catch {
    await dependencies.fail(claim.leaseToken, 'ERR_PROVIDER_UNAVAILABLE');
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
  }
  if (!loaded.ok) {
    await dependencies.fail(claim.leaseToken, loaded.issues[0]?.code ?? 'ERR_PROVIDER_UNAVAILABLE');
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
  }
  return dependencies.publish(claim.leaseToken, loaded.batch.observations, input);
}
