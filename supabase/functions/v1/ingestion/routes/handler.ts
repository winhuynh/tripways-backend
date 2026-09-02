import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import type { IngestRoutesResult } from './service.ts';

export type RouteIngestionLogEvent = {
  request_id: string | null;
  action: 'INGEST_DIRECT_ROUTES';
  status: 'succeeded' | 'failed';
  processed_at: string;
  error_code: string | null;
};

export type RouteIngestionRequestPayload = {
  airports?: string[];
  scope?: 'top_airports' | 'all_eligible';
  limit?: number;
};

export type RouteIngestionHandlerDependencies = {
  workerSecret: string;
  execute(payload: RouteIngestionRequestPayload): Promise<IngestRoutesResult>;
  log(event: RouteIngestionLogEvent): void;
};

export function parseRouteIngestionRequest(payload: unknown): RouteIngestionRequestPayload {
  if (!payload || typeof payload !== 'object') {
    throw new Error('ERR_INVALID_REQUEST');
  }

  const obj = payload as Record<string, unknown>;
  const scope =
    typeof obj.scope === 'string' && ['top_airports', 'all_eligible'].includes(obj.scope)
      ? (obj.scope as 'top_airports' | 'all_eligible')
      : undefined;

  const limit = typeof obj.limit === 'number' && obj.limit > 0 && obj.limit <= 1000
    ? obj.limit
    : undefined;

  let airports: string[] | undefined = undefined;
  if (Array.isArray(obj.airports)) {
    airports = obj.airports
      .map((item) => String(item).trim().toUpperCase())
      .filter((iata) => /^[A-Z]{3}$/.test(iata));
  }

  if ((!airports || airports.length === 0) && !scope) {
    throw new Error('ERR_INVALID_REQUEST');
  }

  return { airports, scope, limit };
}

export async function handleRouteIngestionRequest(
  request: Request,
  dependencies: RouteIngestionHandlerDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;

  const requestId = request.headers.get('x-client-request-id')?.slice(0, 100) ?? null;

  try {
    authorizeWorker(request, dependencies.workerSecret);
    const body = await readJson(request);
    const parsed = parseRouteIngestionRequest(body);
    const result = await dependencies.execute(parsed);

    dependencies.log({
      request_id: requestId,
      action: 'INGEST_DIRECT_ROUTES',
      status: 'succeeded',
      processed_at: new Date().toISOString(),
      error_code: null,
    });

    return successResponse(result, 200);
  } catch (error) {
    const errorCode = error instanceof Error && error.message.startsWith('ERR_')
      ? error.message
      : 'ERR_ROUTE_INGESTION_FAILED';

    dependencies.log({
      request_id: requestId,
      action: 'INGEST_DIRECT_ROUTES',
      status: 'failed',
      processed_at: new Date().toISOString(),
      error_code: errorCode,
    });

    return errorResponse(new Error(errorCode));
  }
}

function authorizeWorker(request: Request, expectedSecret: string): void {
  const authorization = request.headers.get('authorization');
  if (
    !expectedSecret ||
    expectedSecret.length < 16 ||
    authorization !== `Bearer ${expectedSecret}`
  ) {
    throw new Error('ERR_INGESTION_UNAUTHORIZED');
  }
}
