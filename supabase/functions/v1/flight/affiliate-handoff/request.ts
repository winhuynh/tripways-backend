export function parseAffiliateHandoffRequest(value: unknown): string {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('ERR_INVALID_REQUEST');
  }
  const input = value as Record<string, unknown>;
  if (
    Object.keys(input).length !== 1 || typeof input.observationRef !== 'string' ||
    !/^obs_[0-9a-f]{32}$/.test(input.observationRef)
  ) throw new Error('ERR_INVALID_REQUEST');
  return input.observationRef;
}
