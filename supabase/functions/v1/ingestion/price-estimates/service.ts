import type { PriceEstimateProviderResult } from './provider-contract.ts';
import type { PriceEstimateIngestionRequest } from './request.ts';

export type PriceEstimatePublicationResult = {
  status: string;
  acceptedCount: number;
  rejectedCount: number;
  errorCode: string | null;
};
export type PriceEstimateAdapter = { load(): Promise<PriceEstimateProviderResult> };
export async function executePriceEstimateIngestion(
  request: PriceEstimateIngestionRequest,
  adapters: ReadonlyMap<string, PriceEstimateAdapter>,
  publish: (args: Record<string, unknown>) => Promise<PriceEstimatePublicationResult>,
): Promise<PriceEstimatePublicationResult> {
  const adapter = adapters.get(request.providerKey);
  if (!adapter) throw new Error('ERR_INGESTION_PROVIDER_NOT_CONFIGURED');
  const result = await adapter.load();
  if (!result.ok) throw new Error('ERR_INGESTION_VALIDATION_FAILED');
  const canonicalJson = JSON.stringify(result.batch);
  const checksum = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(canonicalJson));
  const response = await publish({
    p_source_code: request.sourceCode,
    p_idempotency_key: request.idempotencyKey,
    p_checksum: Array.from(new Uint8Array(checksum)).map((byte) =>
      byte.toString(16).padStart(2, '0')
    ).join(''),
    p_provider_version: result.batch.schemaVersion,
    p_source_time: result.batch.sourceTime,
    p_estimates: result.batch.estimates,
  });
  if (response.status !== 'published' && response.errorCode !== 'ERR_INGESTION_BATCH_DUPLICATE') {
    throw new Error(response.errorCode ?? 'ERR_INGESTION_PUBLISH_FAILED');
  }
  return response;
}
