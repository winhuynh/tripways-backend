import type { ProviderResult } from './provider-contract.ts';
import type { BaseDataIngestionRequest } from './request.ts';

export type PublicationResult = {
  status: string;
  acceptedCount: number;
  rejectedCount: number;
  errorCode: string | null;
  batchId?: string;
  runId?: string;
};

export type BaseDataIngestionDependencies = {
  loadFixture(): Promise<ProviderResult>;
  loadApprovedApi(): Promise<ProviderResult>;
  loadOurAirports(): Promise<ProviderResult>;
  publish(arguments_: Record<string, unknown>): Promise<PublicationResult>;
};

export async function executeBaseDataIngestion(
  request: BaseDataIngestionRequest,
  dependencies: BaseDataIngestionDependencies,
): Promise<PublicationResult> {
  const providerResult = request.providerMode === 'fixture'
    ? await dependencies.loadFixture()
    : request.providerMode === 'ourairports'
    ? await dependencies.loadOurAirports()
    : await dependencies.loadApprovedApi();
  if (!providerResult.ok) throw new Error('ERR_INGESTION_VALIDATION_FAILED');

  const canonicalJson = JSON.stringify(providerResult.batch);
  const checksum = providerResult.batch.importMetadata?.sourceChecksum ??
    await sha256(canonicalJson);
  const result = await dependencies.publish({
    p_source_code: request.sourceCode,
    p_idempotency_key: request.idempotencyKey,
    p_checksum: checksum,
    p_provider_version: providerResult.batch.schemaVersion,
    p_source_time: providerResult.batch.sourceTime,
    p_import_metadata: providerResult.batch.importMetadata ?? null,
    p_records: {
      countries: providerResult.batch.countries,
      cities: providerResult.batch.cities,
      airports: providerResult.batch.airports,
    },
  });
  if (result.errorCode === 'ERR_INGESTION_BATCH_DUPLICATE') return result;
  if (result.errorCode === 'ERR_INGESTION_VALIDATION_FAILED') {
    throw new Error('ERR_INGESTION_VALIDATION_FAILED');
  }
  if (result.errorCode === 'ERR_INGESTION_ANOMALY_REVIEW_REQUIRED') {
    throw new Error('ERR_INGESTION_ANOMALY_REVIEW_REQUIRED');
  }
  if (result.errorCode !== null || result.status !== 'published') {
    throw new Error('ERR_INGESTION_PUBLISH_FAILED');
  }
  return result;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}
