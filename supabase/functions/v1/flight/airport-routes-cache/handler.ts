import type { SupabaseClient } from '@supabase/supabase-js';
import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { extractRequestId, logEdgeError, logEdgeInfo } from '@shared/logger.ts';
import {
  type AeroDataBoxConfig,
  fetchDirectRoutesFromAeroDataBox,
} from '../../ingestion/routes/providers/aerodatabox-provider.ts';
import { type AirportRoutesCacheRequest, parseAirportRoutesCacheRequest } from './request.ts';
import { refreshAirportRoutesCache } from './service.ts';

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
      const serviceDeps = {
        client,
        fetchRoutes: options.fetchRoutes,
        aerodataboxConfig: options.aerodataboxConfig,
        logContext,
      };

      const result = await refreshAirportRoutesCache(parsed.originIata, serviceDeps);
      const durationMs = Math.round(performance.now() - startTime);

      logEdgeInfo('AIRPORT_ROUTES_CACHE_COMPLETED', {
        ...logContext,
        durationMs,
        origin: parsed.originIata,
        status: typeof result.status === 'string' ? result.status : undefined,
      });

      return successResponse(result, 200, { 'x-request-id': requestId });
    } catch (error) {
      logEdgeError('AIRPORT_ROUTES_CACHE_HANDLER_ERROR', error, logContext);
      return errorResponse(error, logContext);
    }
  };
}
