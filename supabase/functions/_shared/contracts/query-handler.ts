import {
  assertMethod,
  cacheableJsonResponse,
  errorResponse,
  jsonResponse,
  readJson,
} from '@shared/edge.ts';
import { extractRequestId, logEdgeInfo } from '@shared/logger.ts';
import { mapRpcEnvelope } from './rpc-envelope.ts';

export type QueryHandlerDependencies<TInput> = {
  parse(value: unknown): TInput;
  query(input: TInput): Promise<unknown>;
  contractErrorCode: string;
  /** Set to true for public, anonymous, read-only endpoints to enable CDN and browser caching. */
  cacheable?: boolean;
};

export function createQueryHandler<TInput>(
  dependencies: QueryHandlerDependencies<TInput>,
): (request: Request) => Promise<Response> {
  return async (request) => {
    const requestId = extractRequestId(request);
    const startTime = performance.now();
    const url = new URL(request.url);
    const logContext = {
      requestId,
      path: url.pathname,
      method: request.method,
    };

    const methodError = assertMethod(request, ['POST'], logContext);
    if (methodError) return methodError;

    try {
      const input = dependencies.parse(await readJson(request));
      const result = await dependencies.query(input);
      const envelope = mapRpcEnvelope(result, dependencies.contractErrorCode);
      const durationMs = Math.round(performance.now() - startTime);

      logEdgeInfo('EDGE_QUERY_SUCCESS', {
        ...logContext,
        durationMs,
      });

      const extraHeaders = { 'x-request-id': requestId };
      return dependencies.cacheable
        ? cacheableJsonResponse(envelope, 200, extraHeaders)
        : jsonResponse(envelope, 200, extraHeaders);
    } catch (error) {
      const durationMs = Math.round(performance.now() - startTime);
      return errorResponse(error, {
        ...logContext,
        durationMs,
      });
    }
  };
}
