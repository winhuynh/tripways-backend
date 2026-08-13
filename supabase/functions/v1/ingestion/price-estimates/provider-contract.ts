export type FlightContentIssueCode =
  | 'ERR_PROVIDER_UNAVAILABLE'
  | 'ERR_PROVIDER_RATE_LIMITED'
  | 'ERR_INVALID_PROVIDER_PAYLOAD'
  | 'ERR_UNSUPPORTED_SCHEMA_VERSION'
  | 'ERR_MISSING_REQUIRED_FIELD'
  | 'ERR_DUPLICATE_SOURCE_KEY'
  | 'ERR_INVALID_AMOUNT'
  | 'ERR_INVALID_CURRENCY'
  | 'ERR_INVALID_VALIDITY_WINDOW'
  | 'ERR_INVALID_AFFILIATE_REFERENCE';

export type FlightContentObservation = {
  sourceId: string;
  observationType: 'popular_direction' | 'cached_fare' | 'special_offer' | 'price_calendar';
  originCode: string;
  destinationCode: string;
  originAirportIata: string | null;
  destinationAirportIata: string | null;
  airlineIata: string | null;
  tripType: 'one_way' | 'return';
  direct: boolean | null;
  transferCount: number | null;
  amount: number | null;
  currencyCode: string | null;
  marketCode: string;
  locale: string;
  departureDate: string | null;
  returnDate: string | null;
  durationMinutes: number | null;
  foundAt: string;
  providerExpiresAt: string | null;
  validUntil: string;
  affiliatePath: string | null;
};

export type FlightContentObservationBatch = {
  schemaVersion: 'flight-content-observations.v1';
  sourceTime: string | null;
  observations: FlightContentObservation[];
};

export type FlightContentProviderResult =
  | { ok: true; batch: FlightContentObservationBatch }
  | { ok: false; issues: Array<{ code: FlightContentIssueCode; sourceKey: string | null }> };

export function parseFlightContentObservationBatch(payload: unknown): FlightContentProviderResult {
  if (!isRecord(payload)) return failure('ERR_INVALID_PROVIDER_PAYLOAD');
  if (payload.schemaVersion !== 'flight-content-observations.v1') {
    return failure('ERR_UNSUPPORTED_SCHEMA_VERSION');
  }
  if (!Array.isArray(payload.observations)) return failure('ERR_INVALID_PROVIDER_PAYLOAD');

  const issues: Array<{ code: FlightContentIssueCode; sourceKey: string | null }> = [];
  const observations: FlightContentObservation[] = [];
  const sourceIds = new Set<string>();
  for (const raw of payload.observations) {
    if (!isRecord(raw)) {
      issues.push({ code: 'ERR_INVALID_PROVIDER_PAYLOAD', sourceKey: null });
      continue;
    }
    const sourceId = stringField(raw, 'sourceId');
    const originCode = codeField(raw, 'originCode', 3);
    const destinationCode = codeField(raw, 'destinationCode', 3);
    const marketCode = lowerCodeField(raw, 'marketCode', 2);
    const locale = stringField(raw, 'locale');
    const foundAt = stringField(raw, 'foundAt');
    const validUntil = stringField(raw, 'validUntil');
    if (
      !sourceId || !originCode || !destinationCode || !marketCode || !locale || !foundAt ||
      !validUntil
    ) {
      issues.push({ code: 'ERR_MISSING_REQUIRED_FIELD', sourceKey: sourceId });
      continue;
    }
    if (sourceIds.has(sourceId)) {
      issues.push({ code: 'ERR_DUPLICATE_SOURCE_KEY', sourceKey: sourceId });
      continue;
    }
    sourceIds.add(sourceId);
    if (raw.amount !== null && !finiteNonNegative(raw.amount)) {
      issues.push({ code: 'ERR_INVALID_AMOUNT', sourceKey: sourceId });
    }
    if (
      raw.currencyCode !== null &&
      (typeof raw.currencyCode !== 'string' || !/^[A-Z]{3}$/.test(raw.currencyCode))
    ) {
      issues.push({ code: 'ERR_INVALID_CURRENCY', sourceKey: sourceId });
    }
    const providerExpiresAt = optionalString(raw.providerExpiresAt);
    if (!validObservationWindow(foundAt, validUntil, providerExpiresAt)) {
      issues.push({ code: 'ERR_INVALID_VALIDITY_WINDOW', sourceKey: sourceId });
    }
    const affiliatePath = optionalString(raw.affiliatePath);
    if (
      affiliatePath !== null && (!affiliatePath.startsWith('/') || affiliatePath.startsWith('//'))
    ) {
      issues.push({ code: 'ERR_INVALID_AFFILIATE_REFERENCE', sourceKey: sourceId });
    }
    if (issues.some((issue) => issue.sourceKey === sourceId)) continue;
    if (
      !isEnum(raw.observationType, [
        'popular_direction',
        'cached_fare',
        'special_offer',
        'price_calendar',
      ]) ||
      !isEnum(raw.tripType, ['one_way', 'return']) ||
      (raw.direct !== null && typeof raw.direct !== 'boolean') ||
      (raw.transferCount !== null &&
        (!Number.isInteger(raw.transferCount) || Number(raw.transferCount) < 0)) ||
      (raw.durationMinutes !== null &&
        (!Number.isInteger(raw.durationMinutes) || Number(raw.durationMinutes) <= 0))
    ) {
      issues.push({ code: 'ERR_INVALID_PROVIDER_PAYLOAD', sourceKey: sourceId });
      continue;
    }
    observations.push({
      sourceId,
      observationType: raw.observationType,
      originCode,
      destinationCode,
      originAirportIata: optionalCode(raw.originAirportIata, 3),
      destinationAirportIata: optionalCode(raw.destinationAirportIata, 3),
      airlineIata: optionalCode(raw.airlineIata, 2),
      tripType: raw.tripType,
      direct: raw.direct,
      transferCount: raw.transferCount as number | null,
      amount: raw.amount as number | null,
      currencyCode: raw.currencyCode as string | null,
      marketCode,
      locale,
      departureDate: optionalDate(raw.departureDate),
      returnDate: optionalDate(raw.returnDate),
      durationMinutes: raw.durationMinutes as number | null,
      foundAt,
      providerExpiresAt,
      validUntil,
      affiliatePath,
    });
  }
  return issues.length ? { ok: false, issues } : {
    ok: true,
    batch: {
      schemaVersion: 'flight-content-observations.v1',
      sourceTime: optionalString(payload.sourceTime),
      observations,
    },
  };
}

function validObservationWindow(
  foundAt: string,
  validUntil: string,
  providerExpiresAt: string | null,
): boolean {
  const found = Date.parse(foundAt);
  const valid = Date.parse(validUntil);
  const providerExpiry = providerExpiresAt === null ? null : Date.parse(providerExpiresAt);
  return Number.isFinite(found) && Number.isFinite(valid) && valid > found &&
    valid <= found + 604_800_000 &&
    (providerExpiry === null || (Number.isFinite(providerExpiry) && valid <= providerExpiry));
}
function failure(code: FlightContentIssueCode): FlightContentProviderResult {
  return { ok: false, issues: [{ code, sourceKey: null }] };
}
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
function stringField(value: Record<string, unknown>, key: string): string | null {
  return typeof value[key] === 'string' && value[key].trim() ? value[key].trim() : null;
}
function optionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}
function codeField(value: Record<string, unknown>, key: string, length: number): string | null {
  return optionalCode(value[key], length);
}
function lowerCodeField(
  value: Record<string, unknown>,
  key: string,
  length: number,
): string | null {
  const result = optionalString(value[key])?.toLowerCase() ?? null;
  return result && new RegExp(`^[a-z]{${length}}$`).test(result) ? result : null;
}
function optionalCode(value: unknown, length: number): string | null {
  const result = optionalString(value)?.toUpperCase() ?? null;
  return result && new RegExp(`^[A-Z0-9]{${length}}$`).test(result) ? result : null;
}
function optionalDate(value: unknown): string | null {
  const result = optionalString(value);
  return result && /^\d{4}-\d{2}-\d{2}$/.test(result) ? result : null;
}
function finiteNonNegative(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0;
}
function isEnum<T extends string>(value: unknown, allowed: readonly T[]): value is T {
  return typeof value === 'string' && allowed.includes(value as T);
}
