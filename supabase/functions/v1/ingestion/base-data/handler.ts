import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { buildRateLimitSubjectHashes } from '@shared/rate_limit.ts';
import type { PublicationResult } from './service.ts';
import { parseBaseDataIngestionRequest } from './request.ts';

export type BaseDataIngestionLogEvent = {
  request_id: string | null;
  action: 'INGEST_BASE_DATA';
  status: 'succeeded' | 'failed';
  processed_at: string;
  error_code: string | null;
};

export type BaseDataIngestionHandlerDependencies = {
  workerSecret: string;
  rateLimit(subjectHash: string): Promise<void>;
  execute(request: ReturnType<typeof parseBaseDataIngestionRequest>): Promise<PublicationResult>;
  log(event: BaseDataIngestionLogEvent): void;
};

export async function handleBaseDataIngestionRequest(
  request: Request,
  dependencies: BaseDataIngestionHandlerDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;

  const requestId = request.headers.get('x-client-request-id')?.slice(0, 100) ?? null;
  try {
    authorizeWorker(request, dependencies.workerSecret);
    const subjects = await buildRateLimitSubjectHashes('base-data-worker', request);
    await Promise.all(subjects.map((subject) => dependencies.rateLimit(subject)));
    const input = parseBaseDataIngestionRequest(
      await readJson(request),
      request.headers.get('idempotency-key'),
    );
    const result = await dependencies.execute(input);
    dependencies.log({
      request_id: requestId,
      action: 'INGEST_BASE_DATA',
      status: 'succeeded',
      processed_at: new Date().toISOString(),
      error_code: result.errorCode,
    });
    return successResponse(
      result,
      result.errorCode === 'ERR_INGESTION_BATCH_DUPLICATE' ? 409 : 200,
    );
  } catch (error) {
    const errorCode = error instanceof Error && error.message.startsWith('ERR_')
      ? error.message
      : 'ERR_INGESTION_PUBLISH_FAILED';
    dependencies.log({
      request_id: requestId,
      action: 'INGEST_BASE_DATA',
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
    expectedSecret.length < 16 ||
    authorization !== `Bearer ${expectedSecret}`
  ) {
    throw new Error('ERR_INGESTION_UNAUTHORIZED');
  }
}
