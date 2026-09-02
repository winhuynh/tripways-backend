import type { SupabaseClient } from '@supabase/supabase-js';
import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { extractRequestId, logEdgeError, logEdgeInfo, logEdgeWarn } from '@shared/logger.ts';
import {
  fetchRoutePricesFromTravelpayouts,
  type NormalizedPriceObservation,
  type TravelpayoutsConfig,
} from '../../ingestion/price-estimates/providers/travelpayouts-provider.ts';
import { parseRouteCacheRequest, type RouteCacheRequest } from './request.ts';

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
      const adminClient = (typeof client.schema === 'function' ? client.schema('admin') : client) ??
        client;

      const leaseParams = {
        p_origin_iata: parsed.originIata,
        p_destination_iata: parsed.destIata ?? null,
        p_currency_code: parsed.currency ?? 'USD',
        p_market_code: parsed.market ?? 'us',
      };

      const { data: leaseData, error: leaseError } = await adminClient.rpc(
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
        const durationMs = Math.round(performance.now() - startTime);
        logEdgeInfo('ROUTE_CACHE_HIT_FRESH', {
          ...logContext,
          durationMs,
          origin: parsed.originIata,
          destination: parsed.destIata,
        });
        return successResponse(leaseObj, 200, { 'x-request-id': requestId });
      }

      if (leaseObj.status === 'lease_acquired') {
        const fetchPrices = options.fetchProviderPrices ?? fetchRoutePricesFromTravelpayouts;
        const config: TravelpayoutsConfig = options.travelpayoutsConfig ?? {
          token: Deno.env.get('TRAVELPAYOUTS_TOKEN') ?? Deno.env.get('TRAVELPAYOUTS_API_TOKEN'),
        };

        let observations: NormalizedPriceObservation[] = [];
        try {
          observations = await fetchPrices(config, {
            originIata: parsed.originIata,
            destIata: parsed.destIata,
            currency: parsed.currency,
            market: parsed.market,
            locale: parsed.locale,
          });
        } catch (providerError) {
          logEdgeWarn('ROUTE_CACHE_PROVIDER_FETCH_FAILED', providerError, logContext);
        }

        const publishParams = {
          p_origin_iata: parsed.originIata,
          p_destination_iata: parsed.destIata ?? null,
          p_currency_code: parsed.currency ?? 'USD',
          p_market_code: parsed.market ?? 'us',
          p_observations: observations,
        };

        const { data: publishData, error: publishError } = await adminClient.rpc(
          'rpc_publish_price_observations',
          publishParams,
        );

        if (publishError) {
          logEdgeError('ROUTE_CACHE_PUBLISH_RPC_ERROR', publishError, logContext);
          throw publishError;
        }

        const durationMs = Math.round(performance.now() - startTime);
        logEdgeInfo('ROUTE_CACHE_LEASE_PUBLISHED', {
          ...logContext,
          durationMs,
          origin: parsed.originIata,
          destination: parsed.destIata,
          count: observations.length,
        });

        const result = {
          ...(typeof publishData === 'object' && publishData !== null ? publishData : {}),
          origin: parsed.originIata,
          destination: parsed.destIata ?? null,
          observations,
        };

        return successResponse(result, 200, { 'x-request-id': requestId });
      }

      if (leaseObj.status === 'cooldown') {
        const durationMs = Math.round(performance.now() - startTime);
        logEdgeInfo('ROUTE_CACHE_COOLDOWN', {
          ...logContext,
          durationMs,
          origin: parsed.originIata,
          destination: parsed.destIata,
        });
        return successResponse(
          {
            ...leaseObj,
            status: 'empty',
            origin: parsed.originIata,
            destination: parsed.destIata ?? null,
          },
          200,
          { 'x-request-id': requestId },
        );
      }

      if (leaseObj.status === 'refreshing') {
        const durationMs = Math.round(performance.now() - startTime);
        logEdgeInfo('ROUTE_CACHE_REFRESHING', {
          ...logContext,
          durationMs,
          origin: parsed.originIata,
          destination: parsed.destIata,
        });
        return successResponse(
          {
            ...leaseObj,
            status: 'loading',
            origin: parsed.originIata,
            destination: parsed.destIata ?? null,
          },
          200,
          { 'x-request-id': requestId },
        );
      }

      return successResponse(leaseObj, 200, { 'x-request-id': requestId });
    } catch (error) {
      const durationMs = Math.round(performance.now() - startTime);
      return errorResponse(error, {
        ...logContext,
        durationMs,
      });
    }
  };
}
