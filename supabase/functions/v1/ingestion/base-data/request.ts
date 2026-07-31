export type BaseDataIngestionRequest = {
  sourceCode: string;
  providerMode: 'fixture' | 'approved_api';
  idempotencyKey: string;
};

export function parseBaseDataIngestionRequest(
  value: unknown,
  idempotencyKey: string | null,
): BaseDataIngestionRequest {
  if (!isRecord(value)) throw new Error('ERR_INGESTION_INVALID_REQUEST');
  const sourceCode = value.sourceCode;
  const providerMode = value.providerMode;
  if (
    typeof sourceCode !== 'string' ||
    !/^[a-z0-9]+(?:[_-][a-z0-9]+)*$/.test(sourceCode) ||
    (providerMode !== 'fixture' && providerMode !== 'approved_api') ||
    typeof idempotencyKey !== 'string' ||
    idempotencyKey !== idempotencyKey.trim() ||
    idempotencyKey.length < 8 ||
    idempotencyKey.length > 128
  ) {
    throw new Error('ERR_INGESTION_INVALID_REQUEST');
  }
  return { sourceCode, providerMode, idempotencyKey };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
