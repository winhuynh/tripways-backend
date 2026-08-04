import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { parsePriceEstimateIngestionRequest } from './request.ts';
import type { PriceEstimatePublicationResult } from './service.ts';
export async function handlePriceEstimateIngestionRequest(request: Request, dependencies: {
  workerSecret: string;
  execute(
    input: ReturnType<typeof parsePriceEstimateIngestionRequest>,
  ): Promise<PriceEstimatePublicationResult>;
}): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;
  try {
    if (
      dependencies.workerSecret.length < 16 ||
      request.headers.get('authorization') !== `Bearer ${dependencies.workerSecret}`
    ) throw new Error('ERR_INGESTION_UNAUTHORIZED');
    const input = parsePriceEstimateIngestionRequest(
      await readJson(request),
      request.headers.get('idempotency-key'),
    );
    return successResponse(await dependencies.execute(input));
  } catch (error) {
    return errorResponse(error);
  }
}
