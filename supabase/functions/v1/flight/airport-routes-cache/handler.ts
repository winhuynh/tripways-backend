import type { SupabaseClient } from '@supabase/supabase-js';
import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { extractRequestId, logEdgeError, logEdgeInfo, logEdgeWarn } from '@shared/logger.ts';
import {
  type AeroDataBoxConfig,
  type AeroDataBoxRoute,
  fetchDirectRoutesFromAeroDataBox,
} from '../../ingestion/routes/providers/aerodatabox-provider.ts';
import { type AirportRoutesCacheRequest, parseAirportRoutesCacheRequest } from './request.ts';

export type AirportRoutesCacheHandlerOptions = {
  getSupabaseClient: () => SupabaseClient;
  fetchRoutes?: typeof fetchDirectRoutesFromAeroDataBox;
  aerodataboxConfig?: AeroDataBoxConfig;
};

export function createAirportRoutesCacheHandler(
  options: AirportRoutesCacheHandlerOptions,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    const requestId = extractRequestId(request);
    const startTime = performance.now();
    const logContext = {
      requestId,
      featureArea: 'airport-routes-cache',
      method: request.method,
    };

    const methodError = assertMethod(request, ['GET', 'POST'], logContext);
    if (methodError) return methodError;

    try {
      let parsed: AirportRoutesCacheRequest;
      if (request.method === 'GET') {
        const url = new URL(request.url);
        const queryParams: Record<string, unknown> = {};
        for (const [key, val] of url.searchParams.entries()) {
          queryParams[key] = val;
        }
        parsed = parseAirportRoutesCacheRequest(queryParams);
      } else {
        const body = await readJson(request);
        parsed = parseAirportRoutesCacheRequest(body);
      }

      const client = options.getSupabaseClient();

      // 1. Acquire lease or verify freshness
      const { data: leaseData, error: leaseError } = await client.rpc(
        'rpc_acquire_airport_route_refresh_lease',
        { p_origin_iata: parsed.originIata },
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
        const durationMs = Math.round(performance.now() - startTime);
        logEdgeInfo('AIRPORT_ROUTES_CACHE_HIT_FRESH', {
          ...logContext,
          durationMs,
          origin: parsed.originIata,
          count: leaseObj.count,
        });
        return successResponse(leaseObj, 200, { 'x-request-id': requestId });
      }

      if (leaseObj.status === 'cooldown') {
        const durationMs = Math.round(performance.now() - startTime);
        logEdgeInfo('AIRPORT_ROUTES_CACHE_COOLDOWN', {
          ...logContext,
          durationMs,
          origin: parsed.originIata,
        });
        return successResponse(
          {
            ...leaseObj,
            status: 'empty',
            origin: parsed.originIata,
            routes_count: 0,
          },
          200,
          { 'x-request-id': requestId },
        );
      }

      if (leaseObj.status === 'refreshing') {
        const durationMs = Math.round(performance.now() - startTime);
        logEdgeInfo('AIRPORT_ROUTES_CACHE_REFRESHING', {
          ...logContext,
          durationMs,
          origin: parsed.originIata,
        });
        return successResponse(
          {
            status: 'loading',
            origin: parsed.originIata,
          },
          200,
          { 'x-request-id': requestId },
        );
      }

      if (leaseObj.status === 'lease_acquired') {
        let envApiKey = '';
        try {
          envApiKey = Deno.env.get('AERODATABOX_API_KEY') ?? '';
        } catch {
          // Ignore permission error in test environments
        }

        const config: AeroDataBoxConfig = options.aerodataboxConfig ?? {
          apiKey: envApiKey,
        };

        const fetchFn = options.fetchRoutes ?? fetchDirectRoutesFromAeroDataBox;
        let routes: AeroDataBoxRoute[] = [];
        let fetchSuccess = false;
        let failureCode: string | null = null;

        try {
          routes = await fetchFn(parsed.originIata, config);
          fetchSuccess = true;
        } catch (providerError) {
          logEdgeWarn('AIRPORT_ROUTES_CACHE_PROVIDER_FETCH_FAILED', providerError, logContext);
          failureCode = providerError instanceof Error ? providerError.message : 'ERR_FETCH_FAILED';
        }

        const leaseToken = (leaseObj.lease_token ?? leaseObj.lease_id ?? null) as string | null;

        if (fetchSuccess) {
          if (routes.length > 0) {
            const { error: ingestError } = await client.rpc(
              'rpc_ingest_direct_flight_routes',
              {
                p_source_code: 'aerodatabox',
                p_routes: routes,
              },
            );

            if (ingestError) {
              logEdgeError('AIRPORT_ROUTES_CACHE_INGEST_RPC_ERROR', ingestError, logContext);
              throw ingestError;
            }
          }

          // Finalize lease state as fresh or empty
          const { error: finalizeErr } = await client.rpc(
            'rpc_finalize_airport_route_refresh_lease',
            {
              p_origin_iata: parsed.originIata,
              p_status: routes.length > 0 ? 'fresh' : 'empty',
              p_failure_code: null,
              p_lease_token: leaseToken,
            },
          );

          if (finalizeErr) {
            logEdgeError('AIRPORT_ROUTES_CACHE_FINALIZE_RPC_ERROR', finalizeErr, logContext);
          }

          const durationMs = Math.round(performance.now() - startTime);
          logEdgeInfo('AIRPORT_ROUTES_CACHE_LEASE_COMPLETED', {
            ...logContext,
            durationMs,
            origin: parsed.originIata,
            routesCount: routes.length,
          });

          return successResponse(
            {
              status: routes.length > 0 ? 'fresh' : 'empty',
              origin: parsed.originIata,
              routes_count: routes.length,
            },
            200,
            { 'x-request-id': requestId },
          );
        } else {
          // Finalize lease state as failed
          const sanitizedCode = failureCode ? failureCode.slice(0, 50) : 'ERR_FETCH_FAILED';
          const { error: finalizeErr } = await client.rpc(
            'rpc_finalize_airport_route_refresh_lease',
            {
              p_origin_iata: parsed.originIata,
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
    } catch (error) {
      logEdgeError('AIRPORT_ROUTES_CACHE_HANDLER_ERROR', error, logContext);
      return errorResponse(error, logContext);
    }
  };
}
