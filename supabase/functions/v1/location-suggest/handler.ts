import { createQueryHandler } from '@shared/contracts/query-handler.ts';
import { type LocationSuggestRequest, parseLocationSuggestRequest } from './request.ts';

export function createLocationSuggestHandler(
  query: (input: LocationSuggestRequest) => Promise<unknown>,
): (request: Request) => Promise<Response> {
  return createQueryHandler<LocationSuggestRequest>({
    parse: parseLocationSuggestRequest,
    query,
    contractErrorCode: 'ERR_LOCATION_SUGGEST_CONTRACT',
    cacheable: true,
  });
}
