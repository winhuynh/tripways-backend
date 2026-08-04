export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function assertAllowedFields(
  value: Record<string, unknown>,
  allowed: ReadonlySet<string>,
  errorCode: string,
): void {
  if (Object.keys(value).some((key) => !allowed.has(key))) throw new Error(errorCode);
}
