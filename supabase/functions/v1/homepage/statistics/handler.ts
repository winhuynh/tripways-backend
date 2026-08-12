import { isRecord } from '@shared/contracts/guards.ts';
import { createQueryHandler } from '@shared/contracts/query-handler.ts';

export function createHomepageStatisticsHandler(
  query: () => Promise<unknown>,
): (request: Request) => Promise<Response> {
  return createQueryHandler<void>({
    parse: (value) => {
      if (!isRecord(value) || Object.keys(value).length > 0) {
        throw new Error('ERR_HOMEPAGE_STATISTICS_INVALID_REQUEST');
      }
    },
    query,
    contractErrorCode: 'ERR_HOMEPAGE_STATISTICS_CONTRACT',
    cacheable: true,
  });
}
