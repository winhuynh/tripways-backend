import type { SupabaseClient } from '@supabase/supabase-js';
import { logEdgeError, logEdgeInfo, logEdgeWarn } from '@shared/logger.ts';
import {
  fetchRoutePricesFromTravelpayouts,
  type NormalizedPriceObservation,
  type TravelpayoutsConfig,
} from '../../ingestion/price-estimates/providers/travelpayouts-provider.ts';
import type { RouteCacheRequest } from './request.ts';

export type RouteCacheServiceDependencies = {
  client: SupabaseClient;
  fetchProviderPrices?: typeof fetchRoutePricesFromTravelpayouts;
  travelpayoutsConfig?: TravelpayoutsConfig;
  logContext?: Record<string, unknown>;
};

export type RouteCacheResult = Record<string, unknown>;

export type RouteCacheBatchResult = {
  status: 'success';
  mode: string;
  processed_count: number;
  results: RouteCacheResult[];
};

/**
 * Orchestrates route price cache refresh for a single origin / destination pair.
 * Handles lease acquisition, provider fetching, lease fencing verification, and observation publishing.
 */
export async function refreshRoutePriceCache(
  params: {
    originIata: string;
    destIata?: string;
    currency?: string;
    market?: string;
    locale?: string;
    forceRefresh?: boolean;
  },
  deps: RouteCacheServiceDependencies,
): Promise<RouteCacheResult> {
  const { client, logContext = {} } = deps;
  const { originIata, destIata, currency = 'USD', market = 'us', forceRefresh = false } = params;

  const leaseParams = {
    p_origin_iata: originIata,
    p_destination_iata: destIata ?? null,
    p_currency_code: currency,
    p_market_code: market,
    p_force_refresh: forceRefresh,
  };

  const { data: leaseData, error: leaseError } = await client.rpc(
    'rpc_acquire_price_refresh_lease',
    leaseParams,
  );

  if (leaseError) {
    logEdgeError('ROUTE_CACHE_LEASE_RPC_ERROR', leaseError, logContext);
    throw leaseError;
  }

  if (!leaseData || typeof leaseData !== 'object') {
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
  }

  const leaseObj = leaseData as Record<string, unknown>;

  if (leaseObj.status === 'failed') {
    if (leaseObj.error === 'ERR_INVALID_IATA') {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
  }

  if (leaseObj.status === 'fresh') {
    return leaseObj;
  }

  if (leaseObj.status === 'cooldown') {
    return {
      ...leaseObj,
      status: 'empty',
      origin: originIata,
      destination: destIata ?? null,
      observations: [],
    };
  }

  if (leaseObj.status === 'refreshing') {
    return {
      ...leaseObj,
      status: 'loading',
      origin: originIata,
      destination: destIata ?? null,
    };
  }

  if (leaseObj.status === 'lease_acquired') {
    const fetchPrices = deps.fetchProviderPrices ?? fetchRoutePricesFromTravelpayouts;
    const config: TravelpayoutsConfig = deps.travelpayoutsConfig ?? {
      token: Deno.env.get('TRAVELPAYOUTS_TOKEN') ?? Deno.env.get('TRAVELPAYOUTS_API_TOKEN'),
    };

    let observations: NormalizedPriceObservation[];
    try {
      observations = await fetchPrices(config, {
        originIata,
        destIata,
        currency: params.currency,
        market: params.market,
        locale: params.locale,
      });
    } catch (providerError) {
      logEdgeWarn('ROUTE_CACHE_PROVIDER_FETCH_FAILED', providerError, logContext);
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
    }

    const leaseToken = (leaseObj.lease_token ?? leaseObj.lease_id ?? null) as string | null;

    const publishParams = {
      p_origin_iata: originIata,
      p_destination_iata: destIata ?? null,
      p_currency_code: currency,
      p_market_code: market,
      p_observations: observations,
      p_lease_token: leaseToken,
    };

    const { data: publishData, error: publishError } = await client.rpc(
      'rpc_publish_price_observations',
      publishParams,
    );

    if (publishError) {
      logEdgeError('ROUTE_CACHE_PUBLISH_RPC_ERROR', publishError, logContext);
      throw publishError;
    }

    const pubObj = typeof publishData === 'object' && publishData !== null
      ? (publishData as Record<string, unknown>)
      : {};

    if (pubObj.status === 'failed') {
      logEdgeWarn('ROUTE_CACHE_PUBLISH_FAILED', pubObj, logContext);
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE');
    }

    const publishedCount = typeof pubObj.published_count === 'number'
      ? pubObj.published_count
      : (typeof pubObj.count === 'number' ? pubObj.count : observations.length);

    const finalStatus = pubObj.status === 'empty' || publishedCount === 0 ? 'empty' : 'fresh';

    const finalObservations = Array.isArray(pubObj.observations)
      ? pubObj.observations
      : (publishedCount === 0 ? [] : observations);

    return {
      ...pubObj,
      status: finalStatus,
      origin: originIata,
      destination: destIata ?? null,
      count: publishedCount,
      observations: finalObservations,
    };
  }

  return leaseObj;
}

/**
 * Triggers read-model publication in PostgreSQL when fresh data is ingested.
 */
export async function triggerReadModelPublication(
  client: SupabaseClient,
  logContext: Record<string, unknown> = {},
): Promise<void> {
  try {
    await client.rpc('publish_read_model_version', { p_allow_empty: true });
  } catch (pubErr) {
    logEdgeWarn('ROUTE_CACHE_PUBLISH_FAILED', pubErr, logContext);
  }
}

/**
 * Orchestrates batch route cache warming or day-6 active refresh cron jobs.
 */
export async function runRouteCacheBatchJob(
  request: RouteCacheRequest,
  deps: RouteCacheServiceDependencies,
): Promise<RouteCacheBatchResult> {
  const { client, logContext = {} } = deps;
  let routesToProcess: Array<{ origin: string; dest?: string }> = [];

  if (request.mode === 'warm_top_routes') {
    try {
      const { data: topRoutes } = await client.rpc('rpc_get_top_routes_to_warm', {
        p_limit: 50,
      });
      if (Array.isArray(topRoutes) && topRoutes.length > 0) {
        routesToProcess = topRoutes.map(
          (r: { origin_iata: string; destination_iata?: string }) => ({
            origin: r.origin_iata,
            dest: r.destination_iata,
          }),
        );
      }
    } catch {
      // fallback
    }

    if (routesToProcess.length === 0) {
      routesToProcess = await getFallbackHubRoutes(client);
    }
  } else if (request.mode === 'day6_active_refresh') {
    try {
      const { data: day6Routes } = await client.rpc(
        'rpc_get_day6_active_routes_to_refresh',
        { p_limit: 50 },
      );
      if (Array.isArray(day6Routes) && day6Routes.length > 0) {
        routesToProcess = day6Routes.map(
          (r: { origin_iata: string; destination_iata?: string }) => ({
            origin: r.origin_iata,
            dest: r.destination_iata,
          }),
        );
      }
    } catch {
      // fallback
    }

    if (routesToProcess.length === 0) {
      routesToProcess = await getFallbackHubRoutes(client);
    }
  }

  const forceRefresh = request.mode === 'day6_active_refresh';
  const batchResults: Array<Record<string, unknown>> = [];
  let totalPublishedCount = 0;

  for (const target of routesToProcess) {
    try {
      const itemResult = await refreshRoutePriceCache(
        {
          originIata: target.origin,
          destIata: target.dest,
          currency: request.currency,
          market: request.market,
          locale: request.locale,
          forceRefresh,
        },
        deps,
      );
      batchResults.push(itemResult);
      if (
        itemResult.status === 'fresh' &&
        typeof itemResult.count === 'number' &&
        itemResult.count > 0
      ) {
        totalPublishedCount += itemResult.count;
      }
    } catch (itemErr) {
      logEdgeWarn('ROUTE_CACHE_BATCH_ITEM_FAILED', { target, error: itemErr }, logContext);
    }
  }

  // Link ingestion to publication if new prices published (Finding R5)
  if (totalPublishedCount > 0) {
    await triggerReadModelPublication(client, logContext);
  }

  return {
    status: 'success',
    mode: request.mode ?? 'batch',
    processed_count: batchResults.length,
    results: batchResults,
  };
}

async function getFallbackHubRoutes(
  client: SupabaseClient,
): Promise<Array<{ origin: string; dest?: string }>> {
  let hubIatas = ['SGN', 'SIN', 'BKK'];
  if (typeof client.from === 'function') {
    try {
      const { data: hubs } = await client
        .from('airports')
        .select('iata')
        .or('is_hub.eq.true,iata.in.(SGN,SIN,BKK,HAN,LHR)')
        .eq('status', 'active')
        .order('iata', { ascending: true })
        .limit(10);
      if (hubs && hubs.length > 0) {
        hubIatas = hubs.map((h: { iata: string }) => h.iata);
      }
    } catch {
      // fallback
    }
  }
  return hubIatas.map((h) => ({ origin: h }));
}
