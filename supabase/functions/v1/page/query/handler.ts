import { type PageRequest, parsePageRequest } from '@shared/contracts/page-request.ts';
import { createQueryHandler } from '@shared/contracts/query-handler.ts';
import { type PageRpcInput, toPageRpcInput } from './rpc-input.ts';

export function createPageHandler(
  query: (input: PageRpcInput) => Promise<unknown>,
): (request: Request) => Promise<Response> {
  return createQueryHandler<PageRequest>({
    parse: parsePageRequest,
    query: (input) => query(toPageRpcInput(input)),
    contractErrorCode: 'ERR_PAGE_CONTRACT',
  });
}
