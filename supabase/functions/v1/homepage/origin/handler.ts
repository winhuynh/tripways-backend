import { assertMethod, errorResponse, jsonResponse } from '@shared/edge.ts';
import { isRecord } from '@shared/contracts/guards.ts';
import { type HomepageOriginRpcInput, readVisitorCoordinates } from './geolocation.ts';

export function createHomepageOriginHandler(
  query: (input: HomepageOriginRpcInput) => Promise<unknown>,
): (request: Request) => Promise<Response> {
  return async (request) => {
    const methodError = assertMethod(request, ['GET', 'POST']);
    if (methodError) return methodError;

    try {
      const result = await query(readVisitorCoordinates(request.headers));
      if (!isRecord(result) || result.error !== null || !isRecord(result.data)) {
        throw new Error('ERR_HOMEPAGE_ORIGIN_CONTRACT');
      }
      return jsonResponse(result);
    } catch (error) {
      return errorResponse(error);
    }
  };
}
