import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { extractRequestId, logEdgeInfo } from '@shared/logger.ts';
import { parseAffiliateHandoffRequest } from './request.ts';

type HandoffEnvelope = { data: { url: string; expires_at: string } | null; error: unknown };

export function createAffiliateHandoffHandler(
  resolve: (observationRef: string) => Promise<HandoffEnvelope>,
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
      const observationRef = parseAffiliateHandoffRequest(await readJson(request));
      const result = await resolve(observationRef);
      if (!result.data || result.error) throw new Error('ERR_HANDOFF_UNAVAILABLE');

      const durationMs = Math.round(performance.now() - startTime);
      logEdgeInfo('AFFILIATE_HANDOFF_RESOLVED', {
        ...logContext,
        durationMs,
      });

      return successResponse(result.data, 200, { 'x-request-id': requestId });
    } catch (error) {
      const durationMs = Math.round(performance.now() - startTime);
      return errorResponse(error, {
        ...logContext,
        durationMs,
      });
    }
  };
}
