import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { parseAffiliateHandoffRequest } from './request.ts';

type HandoffEnvelope = { data: { url: string; expires_at: string } | null; error: unknown };

export function createAffiliateHandoffHandler(
  resolve: (observationRef: string) => Promise<HandoffEnvelope>,
) {
  return async (request: Request): Promise<Response> => {
    const methodError = assertMethod(request, ['POST']);
    if (methodError) return methodError;
    try {
      const observationRef = parseAffiliateHandoffRequest(await readJson(request));
      const result = await resolve(observationRef);
      if (!result.data || result.error) throw new Error('ERR_HANDOFF_UNAVAILABLE');
      return successResponse(result.data);
    } catch (error) {
      return errorResponse(error);
    }
  };
}
