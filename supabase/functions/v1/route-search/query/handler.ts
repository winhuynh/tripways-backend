import { createQueryHandler } from '@shared/contracts/query-handler.ts';
import {
  parseRouteSearchRequest,
  type RouteSearchRequest,
} from '@shared/contracts/route-filters.ts';
import { type RouteSearchRpcInput, toRouteSearchRpcInput } from './rpc-input.ts';

export function createRouteSearchHandler(
  query: (input: RouteSearchRpcInput) => Promise<unknown>,
): (request: Request) => Promise<Response> {
  return createQueryHandler<RouteSearchRequest>({
    parse: parseRouteSearchRequest,
    query: (input) => query(toRouteSearchRpcInput(input)),
    contractErrorCode: 'ERR_ROUTE_SEARCH_CONTRACT',
    // Public, anonymous, read-only endpoint — allow CDN and browser caching.
    cacheable: true,
  });
}
