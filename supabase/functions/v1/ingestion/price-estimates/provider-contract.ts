export type PriceEstimateIssueCode =
  | 'ERR_INVALID_PROVIDER_PAYLOAD'
  | 'ERR_UNSUPPORTED_SCHEMA_VERSION'
  | 'ERR_MISSING_REQUIRED_FIELD'
  | 'ERR_DUPLICATE_SOURCE_KEY'
  | 'ERR_INVALID_PRICE_BOUNDS'
  | 'ERR_INVALID_CURRENCY'
  | 'ERR_INVALID_VALIDITY_WINDOW';

export type CanonicalPriceEstimate = {
  sourceId: string;
  originCitySourceId: string;
  destinationCitySourceId: string;
  originAirportIata: string | null;
  destinationAirportIata: string | null;
  airlineIata: string | null;
  tripType: 'one_way' | 'return';
  cabin: 'economy' | 'premium_economy' | 'business' | 'first' | 'any';
  stopBucket: 'direct' | 'one_stop' | 'two_stops' | 'three_stops' | 'any';
  baggageIncluded: boolean | null;
  priceMin: number;
  priceMax: number;
  currencyCode: string;
  estimateMethod: string;
  sampleWindowStart: string;
  sampleWindowEnd: string;
  sampleCount: number | null;
  confidenceScore: number;
  lastVerifiedAt: string;
  validUntil: string;
};

export type CanonicalPriceEstimateBatch = {
  schemaVersion: 'route-price-estimates.v1';
  sourceTime: string | null;
  estimates: CanonicalPriceEstimate[];
};

export type PriceEstimateProviderResult =
  | { ok: true; batch: CanonicalPriceEstimateBatch }
  | { ok: false; issues: Array<{ code: PriceEstimateIssueCode; sourceKey: string | null }> };

export function parseCanonicalPriceEstimateBatch(payload: unknown): PriceEstimateProviderResult {
  if (!isRecord(payload)) return failure('ERR_INVALID_PROVIDER_PAYLOAD');
  if (payload.schemaVersion !== 'route-price-estimates.v1') {
    return failure('ERR_UNSUPPORTED_SCHEMA_VERSION');
  }
  if (!Array.isArray(payload.estimates)) return failure('ERR_INVALID_PROVIDER_PAYLOAD');

  const issues: Array<{ code: PriceEstimateIssueCode; sourceKey: string | null }> = [];
  const estimates: CanonicalPriceEstimate[] = [];
  const sourceIds = new Set<string>();
  for (const raw of payload.estimates) {
    if (!isRecord(raw)) {
      issues.push({ code: 'ERR_INVALID_PROVIDER_PAYLOAD', sourceKey: null });
      continue;
    }
    const sourceId = stringField(raw, 'sourceId');
    const originCitySourceId = stringField(raw, 'originCitySourceId');
    const destinationCitySourceId = stringField(raw, 'destinationCitySourceId');
    const estimateMethod = stringField(raw, 'estimateMethod');
    const sampleWindowStart = stringField(raw, 'sampleWindowStart');
    const sampleWindowEnd = stringField(raw, 'sampleWindowEnd');
    const lastVerifiedAt = stringField(raw, 'lastVerifiedAt');
    const validUntil = stringField(raw, 'validUntil');
    if (
      !sourceId || !originCitySourceId || !destinationCitySourceId || !estimateMethod ||
      !sampleWindowStart || !sampleWindowEnd || !lastVerifiedAt || !validUntil
    ) {
      issues.push({ code: 'ERR_MISSING_REQUIRED_FIELD', sourceKey: sourceId });
      continue;
    }
    if (sourceIds.has(sourceId)) {
      issues.push({ code: 'ERR_DUPLICATE_SOURCE_KEY', sourceKey: sourceId });
      continue;
    }
    sourceIds.add(sourceId);
    if (
      !finiteNonNegative(raw.priceMin) || !finiteNonNegative(raw.priceMax) ||
      raw.priceMin > raw.priceMax
    ) {
      issues.push({ code: 'ERR_INVALID_PRICE_BOUNDS', sourceKey: sourceId });
    }
    if (typeof raw.currencyCode !== 'string' || !/^[A-Z]{3}$/.test(raw.currencyCode)) {
      issues.push({ code: 'ERR_INVALID_CURRENCY', sourceKey: sourceId });
    }
    if (
      !validDateOrder(lastVerifiedAt, validUntil) ||
      !validDateOrder(sampleWindowStart, sampleWindowEnd)
    ) {
      issues.push({ code: 'ERR_INVALID_VALIDITY_WINDOW', sourceKey: sourceId });
    }
    if (issues.some((issue) => issue.sourceKey === sourceId)) continue;
    if (
      !isEnum(raw.tripType, ['one_way', 'return']) ||
      !isEnum(raw.cabin, ['economy', 'premium_economy', 'business', 'first', 'any']) ||
      !isEnum(raw.stopBucket, ['direct', 'one_stop', 'two_stops', 'three_stops', 'any']) ||
      typeof raw.confidenceScore !== 'number' || raw.confidenceScore < 0 ||
      raw.confidenceScore > 1 ||
      (raw.sampleCount !== null &&
        (!Number.isInteger(raw.sampleCount) || (raw.sampleCount as number) < 1)) ||
      (raw.baggageIncluded !== null && typeof raw.baggageIncluded !== 'boolean')
    ) {
      issues.push({ code: 'ERR_INVALID_PROVIDER_PAYLOAD', sourceKey: sourceId });
      continue;
    }
    estimates.push({
      sourceId,
      originCitySourceId,
      destinationCitySourceId,
      originAirportIata: optionalCode(raw.originAirportIata, 3),
      destinationAirportIata: optionalCode(raw.destinationAirportIata, 3),
      airlineIata: optionalCode(raw.airlineIata, 2),
      tripType: raw.tripType,
      cabin: raw.cabin,
      stopBucket: raw.stopBucket,
      baggageIncluded: raw.baggageIncluded,
      priceMin: raw.priceMin as number,
      priceMax: raw.priceMax as number,
      currencyCode: raw.currencyCode as string,
      estimateMethod,
      sampleWindowStart,
      sampleWindowEnd,
      sampleCount: raw.sampleCount as number | null,
      confidenceScore: raw.confidenceScore,
      lastVerifiedAt,
      validUntil,
    });
  }
  if (issues.length) return { ok: false, issues };
  return {
    ok: true,
    batch: {
      schemaVersion: 'route-price-estimates.v1',
      sourceTime: optionalString(payload.sourceTime),
      estimates,
    },
  };
}

function failure(code: PriceEstimateIssueCode): PriceEstimateProviderResult {
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
function optionalCode(value: unknown, length: number): string | null {
  const result = optionalString(value)?.toUpperCase() ?? null;
  return result && new RegExp(`^[A-Z0-9]{${length}}$`).test(result) ? result : null;
}
function finiteNonNegative(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0;
}
function validDateOrder(first: string, second: string): boolean {
  const a = Date.parse(first);
  const b = Date.parse(second);
  return Number.isFinite(a) && Number.isFinite(b) && a < b;
}
function isEnum<T extends string>(value: unknown, allowed: readonly T[]): value is T {
  return typeof value === 'string' && allowed.includes(value as T);
}
