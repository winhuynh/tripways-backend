const DEFAULT_ERROR_CODE = 'ERR_SHARED_INVALID';

export function parseSlug(value: unknown, errorCode = DEFAULT_ERROR_CODE): string {
  if (typeof value !== 'string') invalid(errorCode);
  const result = value.trim().toLowerCase();
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(result)) invalid(errorCode);
  return result;
}

export function parseLocale(
  value: unknown,
  defaultLocale = 'en-GB',
  errorCode = DEFAULT_ERROR_CODE,
): string {
  if (value === undefined) return defaultLocale;
  if (typeof value !== 'string' || !/^[a-z]{2}(?:-[A-Z]{2})?$/.test(value.trim())) {
    invalid(errorCode);
  }
  return value.trim();
}

export function parseCode(value: unknown, length: number, errorCode = DEFAULT_ERROR_CODE): string {
  if (typeof value !== 'string') invalid(errorCode);
  const result = value.trim().toUpperCase();
  if (!new RegExp(`^[A-Z0-9]{${length}}$`).test(result)) invalid(errorCode);
  return result;
}

export function parseCodeList(
  value: unknown,
  length: number,
  errorCode = DEFAULT_ERROR_CODE,
): string[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 50) invalid(errorCode);
  return [...new Set(value.map((item) => parseCode(item, length, errorCode)))];
}

export function parseBoundedInteger(
  value: unknown,
  minimum: number,
  maximum: number,
  errorCode = DEFAULT_ERROR_CODE,
): number {
  if (!Number.isInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    invalid(errorCode);
  }
  return value as number;
}

export function parseNonNegativeNumber(
  value: unknown,
  errorCode = DEFAULT_ERROR_CODE,
): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) invalid(errorCode);
  return value;
}

function invalid(errorCode: string): never {
  throw new Error(errorCode);
}
