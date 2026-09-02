import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { extractRequestId, logEdgeInfo } from '@shared/logger.ts';
import { type AffiliateHandoffRequest, parseAffiliateHandoffRequest } from './request.ts';

export const ALLOWED_AFFILIATE_ORIGIN = 'https://www.aviasales.com';
export const DEFAULT_DISCLOSURE =
  'Tripways may earn a commission if you book through this link. Final price and availability are confirmed by Aviasales.';

export type AffiliateHandoffResult = {
  url: string;
  expires_at: string;
  disclosure: string;
};

export type HandoffEnvelope = {
  data: { url: string; expires_at: string; disclosure?: string } | null;
  error: unknown;
};

export interface FallbackSearchOptions {
  marker?: string;
  subId?: string;
  ttlSeconds?: number;
  disclosure?: string;
}

export function isAllowlistedAviasalesUrl(targetUrl: string): boolean {
  try {
    const parsed = new URL(targetUrl);
    return parsed.protocol === 'https:' && parsed.hostname === 'www.aviasales.com';
  } catch {
    return false;
  }
}

export function buildFallbackSearchHandoff(
  req: Extract<AffiliateHandoffRequest, { type: 'fallback_search' }>,
  options?: FallbackSearchOptions,
): AffiliateHandoffResult {
  let datePart = '';
  if (req.departureDate) {
    const match = req.departureDate.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (match) {
      const month = match[2]!;
      const day = match[3]!;
      datePart = `${day}${month}`;
    }
  }

  const marker = options?.marker || Deno.env.get('TRAVELPAYOUTS_MARKER') ||
    Deno.env.get('AVIASALES_MARKER') || 'tripways';
  const subId = options?.subId || Deno.env.get('AFFILIATE_SUB_ID') || 'fallback_search';
  const ttlSeconds = options?.ttlSeconds ?? 86400;

  const url = new URL(
    `https://www.aviasales.com/search/${req.originIata}${datePart}${req.destIata}`,
  );
  url.searchParams.set('marker', marker);
  url.searchParams.set('sub_id', subId);
  if (req.locale) {
    url.searchParams.set('locale', req.locale);
  }

  const targetUrl = url.toString();
  if (!isAllowlistedAviasalesUrl(targetUrl)) {
    throw new Error('ERR_HANDOFF_UNAVAILABLE');
  }

  const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString();
  const disclosure = options?.disclosure ?? DEFAULT_DISCLOSURE;

  return {
    url: targetUrl,
    expires_at: expiresAt,
    disclosure,
  };
}

export type ObservationResolver = (
  observationRef: string,
) => Promise<HandoffEnvelope> | HandoffEnvelope;

export function createAffiliateHandoffHandler(
  resolveObservation?: ObservationResolver,
  options?: FallbackSearchOptions,
) {
  return async (request: Request): Promise<Response> => {
    const requestId = extractRequestId(request);
    const startTime = performance.now();
    const logContext = {
      requestId,
      featureArea: 'affiliate-handoff',
      method: request.method,
    };

    const methodError = assertMethod(request, ['POST'], logContext);
    if (methodError) return methodError;

    try {
      const payload = parseAffiliateHandoffRequest(await readJson(request));

      let resultData: AffiliateHandoffResult;

      if (payload.type === 'observation') {
        if (!resolveObservation) {
          throw new Error('ERR_HANDOFF_UNAVAILABLE');
        }
        const result = await resolveObservation(payload.observationRef);
        if (!result.data || result.error) throw new Error('ERR_HANDOFF_UNAVAILABLE');
        if (!isAllowlistedAviasalesUrl(result.data.url)) {
          throw new Error('ERR_HANDOFF_UNAVAILABLE');
        }
        resultData = {
          url: result.data.url,
          expires_at: result.data.expires_at,
          disclosure: result.data.disclosure || DEFAULT_DISCLOSURE,
        };
      } else {
        resultData = buildFallbackSearchHandoff(payload, options);
      }

      const durationMs = Math.round(performance.now() - startTime);
      logEdgeInfo('AFFILIATE_HANDOFF_RESOLVED', {
        ...logContext,
        handoffType: payload.type,
        durationMs,
      });

      return successResponse(resultData, 200, { 'x-request-id': requestId });
    } catch (error) {
      const durationMs = Math.round(performance.now() - startTime);
      return errorResponse(error, {
        ...logContext,
        durationMs,
      });
    }
  };
}
