import type { SupabaseClient } from '@supabase/supabase-js';
import { logEdgeError, logEdgeWarn } from '@shared/logger.ts';
import {
  type AeroDataBoxConfig,
  type AeroDataBoxRoute,
  fetchDirectRoutesFromAeroDataBox,
} from '../../ingestion/routes/providers/aerodatabox-provider.ts';

export type AirportRoutesCacheServiceDependencies = {
  client: SupabaseClient;
  fetchRoutes?: typeof fetchDirectRoutesFromAeroDataBox;
  aerodataboxConfig?: AeroDataBoxConfig;
  logContext?: Record<string, unknown>;
};

export type AirportRoutesCacheResult = Record<string, unknown>;

/**
 * Orchestrates airport route cache refresh for an origin airport.
 * Handles lease acquisition, AeroDataBox fetching, route batch ingestion, lease finalization,
 * and read model auto-publication.
 */
export async function refreshAirportRoutesCache(
  originIata: string,
  deps: AirportRoutesCacheServiceDependencies,
): Promise<AirportRoutesCacheResult> {
  const { client, logContext = {} } = deps;

  // 1. Acquire lease or verify freshness
  const { data: leaseData, error: leaseError } = await client.rpc(
    'rpc_acquire_airport_route_refresh_lease',
    { p_origin_iata: originIata },
  );

  if (leaseError) {
    logEdgeError('AIRPORT_ROUTES_CACHE_LEASE_RPC_ERROR', leaseError, logContext);
    throw leaseError;
  }

  if (!leaseData || typeof leaseData !== 'object') {
    throw new Error('ERR_AIRPORT_ROUTES_CACHE_UNAVAILABLE');
  }

  const leaseObj = leaseData as Record<string, unknown>;

  if (leaseObj.status === 'failed') {
    if (leaseObj.error === 'ERR_INVALID_IATA') {
      throw new Error('ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST');
    }
    if (leaseObj.error === 'ERR_UNKNOWN_AIRPORT') {
      throw new Error('ERR_AIRPORT_ROUTES_CACHE_UNKNOWN_AIRPORT');
    }
    throw new Error('ERR_AIRPORT_ROUTES_CACHE_UNAVAILABLE');
  }

  if (leaseObj.status === 'fresh') {
    return leaseObj;
  }

  if (leaseObj.status === 'cooldown') {
    return {
      ...leaseObj,
      status: 'empty',
      origin: originIata,
      routes_count: 0,
    };
  }

  if (leaseObj.status === 'refreshing') {
    return {
      status: 'loading',
      origin: originIata,
    };
  }

  if (leaseObj.status === 'lease_acquired') {
    let envApiKey = '';
    try {
      envApiKey = Deno.env.get('AERODATABOX_API_KEY') ?? '';
    } catch {
      // Ignore permission error in test environments
    }

    const config: AeroDataBoxConfig = deps.aerodataboxConfig ?? {
      apiKey: envApiKey,
    };

    const fetchFn = deps.fetchRoutes ?? fetchDirectRoutesFromAeroDataBox;
    let routes: AeroDataBoxRoute[] = [];
    let fetchSuccess = false;
    let failureCode: string | null = null;

    try {
      routes = await fetchFn(originIata, config);
      fetchSuccess = true;
    } catch (providerError) {
      logEdgeWarn('AIRPORT_ROUTES_CACHE_PROVIDER_FETCH_FAILED', providerError, logContext);
      failureCode = providerError instanceof Error ? providerError.message : 'ERR_FETCH_FAILED';
    }

    const leaseToken = (leaseObj.lease_token ?? leaseObj.lease_id ?? null) as string | null;

    if (fetchSuccess) {
      let upsertedCount = routes.length;
      if (routes.length > 0) {
        const { data: ingestData, error: ingestError } = await client.rpc(
          'rpc_ingest_direct_flight_routes',
          {
            p_source_code: 'aerodatabox',
            p_routes: routes,
            p_origin_iata: originIata,
            p_lease_token: leaseToken,
          },
        );

        if (ingestError) {
          logEdgeError('AIRPORT_ROUTES_CACHE_INGEST_RPC_ERROR', ingestError, logContext);
          throw ingestError;
        }

        if (
          ingestData &&
          typeof ingestData === 'object' &&
          (ingestData as Record<string, unknown>).status === 'failed'
        ) {
          logEdgeWarn('AIRPORT_ROUTES_CACHE_INGEST_FAILED', ingestData, logContext);
          throw new Error('ERR_AIRPORT_ROUTES_CACHE_UNAVAILABLE');
        }

        if (
          ingestData &&
          typeof ingestData === 'object' &&
          typeof (ingestData as Record<string, unknown>).upserted_count === 'number'
        ) {
          upsertedCount = (ingestData as Record<string, unknown>).upserted_count as number;
        }
      } else {
        upsertedCount = 0;
      }

      const leaseFinalStatus = upsertedCount > 0 ? 'fresh' : 'empty';

      // Finalize lease state as fresh or empty
      const { data: finalizeData, error: finalizeErr } = await client.rpc(
        'rpc_finalize_airport_route_refresh_lease',
        {
          p_origin_iata: originIata,
          p_status: leaseFinalStatus,
          p_failure_code: null,
          p_lease_token: leaseToken,
        },
      );

      if (finalizeErr) {
        logEdgeError('AIRPORT_ROUTES_CACHE_FINALIZE_RPC_ERROR', finalizeErr, logContext);
        throw finalizeErr;
      }

      if (
        finalizeData &&
        typeof finalizeData === 'object' &&
        (finalizeData as Record<string, unknown>).status === 'failed'
      ) {
        logEdgeWarn('AIRPORT_ROUTES_CACHE_FINALIZE_FAILED', finalizeData, logContext);
        throw new Error('ERR_AIRPORT_ROUTES_CACHE_UNAVAILABLE');
      }

      // Link ingestion to publication (Finding R5)
      if (upsertedCount > 0) {
        try {
          await client.rpc('publish_read_model_version', { p_allow_empty: true });
        } catch (pubErr) {
          logEdgeWarn('AIRPORT_ROUTES_CACHE_PUBLISH_FAILED', pubErr, logContext);
        }
      }

      return {
        status: leaseFinalStatus,
        origin: originIata,
        routes_count: upsertedCount,
      };
    } else {
      // Finalize lease state as failed
      const sanitizedCode = failureCode ? failureCode.slice(0, 50) : 'ERR_FETCH_FAILED';
      const { error: finalizeErr } = await client.rpc(
        'rpc_finalize_airport_route_refresh_lease',
        {
          p_origin_iata: originIata,
          p_status: 'failed',
          p_failure_code: sanitizedCode,
          p_lease_token: leaseToken,
        },
      );

      if (finalizeErr) {
        logEdgeError('AIRPORT_ROUTES_CACHE_FINALIZE_RPC_ERROR', finalizeErr, logContext);
      }

      throw new Error('ERR_AIRPORT_ROUTES_CACHE_UNAVAILABLE');
    }
  }

  throw new Error('ERR_AIRPORT_ROUTES_CACHE_UNAVAILABLE');
}
