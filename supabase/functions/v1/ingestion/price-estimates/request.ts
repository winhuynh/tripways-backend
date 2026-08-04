export type PriceEstimateIngestionRequest = {
  sourceCode: string;
  providerKey: string;
  idempotencyKey: string;
};
export function parsePriceEstimateIngestionRequest(
  value: unknown,
  idempotencyKey: string | null,
): PriceEstimateIngestionRequest {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('ERR_INGESTION_INVALID_REQUEST');
  }
  const input = value as Record<string, unknown>;
  if (
    typeof input.sourceCode !== 'string' ||
    !/^[a-z0-9]+(?:[_-][a-z0-9]+)*$/.test(input.sourceCode) ||
    typeof input.providerKey !== 'string' ||
    !/^[a-z0-9]+(?:[_-][a-z0-9]+)*$/.test(input.providerKey) ||
    typeof idempotencyKey !== 'string' || idempotencyKey.length < 8 || idempotencyKey.length > 128
  ) {
    throw new Error('ERR_INGESTION_INVALID_REQUEST');
  }
  return { sourceCode: input.sourceCode, providerKey: input.providerKey, idempotencyKey };
}
