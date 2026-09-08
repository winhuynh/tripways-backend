import type { SupabaseClient } from '@supabase/supabase-js';
import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { extractRequestId, logEdgeInfo } from '@shared/logger.ts';
import {
  fetchRoutePricesFromTravelpayouts,
  type TravelpayoutsConfig,
} from '../../ingestion/price-estimates/providers/travelpayouts-provider.ts';
import { parseRouteCacheRequest, type RouteCacheRequest } from './request.ts';
import {
  refreshRoutePriceCache,
  runRouteCacheBatchJob,
  triggerReadModelPublication,
} from './service.ts';

export type RouteCacheHandlerOptions = {
  getSupabaseClient: () => SupabaseClient;
  fetchProviderPrices?: typeof fetchRoutePricesFromTravelpayouts;
  travelpayoutsConfig?: TravelpayoutsConfig;
};

export function createRouteCacheHandler(
  options: RouteCacheHandlerOptions,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    const requestId = extractRequestId(request);
    const startTime = performance.now();
    const logContext = {
      requestId,
      featureArea: 'flight-route-cache',
      method: request.method,
    };

    const methodError = assertMethod(request, ['GET', 'POST'], logContext);
    if (methodError) return methodError;

    try {
      let parsed: RouteCacheRequest;
      if (request.method === 'GET') {
        const url = new URL(request.url);
        const queryParams: Record<string, unknown> = {};
        for (const [key, val] of url.searchParams.entries()) {
          queryParams[key] = val;
        }
        parsed = parseRouteCacheRequest(queryParams);
      } else {
        const body = await readJson(request);
        parsed = parseRouteCacheRequest(body);
      }

      const client = options.getSupabaseClient();
      const serviceDeps = {
        client,
        fetchProviderPrices: options.fetchProviderPrices,
        travelpayoutsConfig: options.travelpayoutsConfig,
        logContext,
      };

      // 1. Batch Cron Mode (e.g. warm_top_routes, day6_active_refresh)
      if (!parsed.originIata && parsed.mode) {
        const batchResult = await runRouteCacheBatchJob(parsed, serviceDeps);
        const durationMs = Math.round(performance.now() - startTime);

        logEdgeInfo('ROUTE_CACHE_BATCH_COMPLETED', {
          ...logContext,
          durationMs,
          mode: parsed.mode,
          processedCount: batchResult.processed_count,
        });

        return successResponse(batchResult, 200, { 'x-request-id': requestId });
      }

      // 2. Single Route Mode
      const originIata = parsed.originIata!;
      const forceRefresh = parsed.mode === 'day6_active_refresh';

      const result = await refreshRoutePriceCache(
        {
          originIata,
          destIata: parsed.destIata,
          currency: parsed.currency,
          market: parsed.market,
          locale: parsed.locale,
          forceRefresh,
        },
        serviceDeps,
      );

      // Link ingestion to publication if new prices were published (Finding R5)
      if (result.status === 'fresh' && typeof result.count === 'number' && result.count > 0) {
        await triggerReadModelPublication(client, logContext);
      }

      const durationMs = Math.round(performance.now() - startTime);
      logEdgeInfo('ROUTE_CACHE_COMPLETED', {
        ...logContext,
        durationMs,
        origin: originIata,
        destination: parsed.destIata,
        status: typeof result.status === 'string' ? result.status : undefined,
      });

      return successResponse(result, 200, { 'x-request-id': requestId });
    } catch (error) {
      const durationMs = Math.round(performance.now() - startTime);
      return errorResponse(error, {
        ...logContext,
        durationMs,
      });
    }
  };
}
