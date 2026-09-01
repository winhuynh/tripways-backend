import { assertAllowedFields, isRecord } from './guards.ts';
import {
  parseBoundedInteger,
  parseCode,
  parseCodeList,
  parseNonNegativeNumber,
  parseSlug,
} from './primitives.ts';

const ERROR_CODE = 'ERR_ROUTE_SEARCH_INVALID_REQUEST';
const ROOT_FIELDS = new Set(['scope', 'filters', 'page_size', 'after']);
const FILTER_FIELDS = new Set([
  'max_stops',
  'airlines',
  'connection_airports',
  'departure_airports',
  'destination_countries',
  'destination_regions',
  'counterpart_query',
  'counterpart_countries',
  'counterpart_regions',
  'departure_time_buckets',
  'days_of_week',
  'route_type',
  'max_duration_minutes',
  'max_layover_minutes',
  'cabin',
  'price_max',
  'currency',
]);
const AIRPORT_DISALLOWED_FILTER_FIELDS = [
  'max_stops',
  'connection_airports',
  'departure_airports',
  'destination_countries',
  'destination_regions',
  'departure_time_buckets',
  'days_of_week',
  'max_duration_minutes',
  'max_layover_minutes',
  'cabin',
  'price_max',
  'currency',
] as const;

export type RouteSearchScope =
  | { type: 'global' }
  | { type: 'origin_city'; key: string }
  | { type: 'origin_airport'; key: string }
  | { type: 'airport'; key: string; direction: 'from' | 'to' }
  | { type: 'city_pair'; from: string; to: string };

export type RouteSearchFilters = {
  maxStops: 0 | 1;
  airlines: string[];
  connectionAirports: string[];
  departureAirports: string[];
  destinationCountries: string[];
  destinationRegions: string[];
  counterpartQuery: string | null;
  counterpartCountries: string[];
  counterpartRegions: string[];
  departureTimeBuckets: Array<'early_morning' | 'morning' | 'afternoon' | 'evening'>;
  daysOfWeek: number[];
  routeType: 'all' | 'domestic' | 'international';
  maxDurationMinutes: number | null;
  maxLayoverMinutes: number | null;
  cabin: 'any' | 'economy' | 'premium_economy' | 'business' | 'first';
  priceMax: number | null;
  currency: string | null;
};

export type RouteSearchRequest = {
  scope: RouteSearchScope;
  filters: RouteSearchFilters;
  pageSize: number;
  after: string | null;
};

export function parseRouteSearchRequest(value: unknown): RouteSearchRequest {
  if (!isRecord(value) || !isRecord(value.scope) || !isRecord(value.filters)) invalid();
  assertAllowedFields(value, ROOT_FIELDS, ERROR_CODE);
  assertAllowedFields(value.filters, FILTER_FIELDS, ERROR_CODE);
  const filters = value.filters;
  const scope = parseScope(value.scope);
  if (
    scope.type === 'airport' &&
    AIRPORT_DISALLOWED_FILTER_FIELDS.some((field) => Object.hasOwn(filters, field))
  ) invalid();
  const cabin = filters.cabin ?? 'any';
  if (!['any', 'economy', 'premium_economy', 'business', 'first'].includes(String(cabin))) {
    invalid();
  }
  const routeType = filters.route_type ?? 'all';
  if (!['all', 'domestic', 'international'].includes(String(routeType))) invalid();
  const priceMax = filters.price_max === undefined
    ? null
    : parseNonNegativeNumber(filters.price_max, ERROR_CODE);
  const currency = filters.currency === undefined
    ? null
    : parseCode(filters.currency, 3, ERROR_CODE);
  if ((priceMax === null) !== (currency === null)) invalid();
  return {
    scope,
    filters: {
      maxStops: parseBoundedInteger(filters.max_stops ?? 1, 0, 1, ERROR_CODE) as 0 | 1,
      airlines: parseCodeList(filters.airlines, 2, ERROR_CODE),
      connectionAirports: parseCodeList(filters.connection_airports, 3, ERROR_CODE),
      departureAirports: parseCodeList(filters.departure_airports, 3, ERROR_CODE),
      destinationCountries: parseCodeList(filters.destination_countries, 2, ERROR_CODE),
      destinationRegions: parseTextList(filters.destination_regions),
      counterpartQuery: parseOptionalQuery(filters.counterpart_query),
      counterpartCountries: parseCodeList(filters.counterpart_countries, 2, ERROR_CODE),
      counterpartRegions: parseTextList(filters.counterpart_regions),
      departureTimeBuckets: parseEnumList(
        filters.departure_time_buckets,
        ['early_morning', 'morning', 'afternoon', 'evening'] as const,
      ),
      daysOfWeek: parseIntegerList(filters.days_of_week, 1, 7),
      routeType: routeType as RouteSearchFilters['routeType'],
      maxDurationMinutes: optionalPositiveInteger(filters.max_duration_minutes),
      maxLayoverMinutes: optionalPositiveInteger(filters.max_layover_minutes),
      cabin: cabin as RouteSearchFilters['cabin'],
      priceMax,
      currency,
    },
    pageSize: parseBoundedInteger(value.page_size ?? 20, 1, 100, ERROR_CODE),
    after: parseCursor(value.after),
  };
}

function parseScope(value: Record<string, unknown>): RouteSearchScope {
  if (value.type === 'global' && Object.keys(value).length === 1) return { type: 'global' };
  if (value.type === 'origin_city' && Object.keys(value).length === 2) {
    return { type: 'origin_city', key: parseSlug(value.key, ERROR_CODE) };
  }
  if (value.type === 'origin_airport' && Object.keys(value).length === 2) {
    return { type: 'origin_airport', key: parseCode(value.key, 3, ERROR_CODE) };
  }
  if (value.type === 'airport' && Object.keys(value).length === 3) {
    if (value.direction !== 'from' && value.direction !== 'to') invalid();
    return {
      type: 'airport',
      key: parseCode(value.key, 3, ERROR_CODE),
      direction: value.direction,
    };
  }
  if (value.type === 'city_pair' && Object.keys(value).length === 3) {
    const from = parseSlug(value.from, ERROR_CODE);
    const to = parseSlug(value.to, ERROR_CODE);
    if (from === to) invalid();
    return { type: 'city_pair', from, to };
  }
  invalid();
}

function parseOptionalQuery(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string') invalid();
  const query = value.trim().toLowerCase();
  if (query.length < 1 || query.length > 80) invalid();
  return query;
}

function optionalPositiveInteger(value: unknown): number | null {
  return value === undefined ? null : parseBoundedInteger(value, 1, 10080, ERROR_CODE);
}

function parseTextList(value: unknown): string[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 50) invalid();
  const values = value.map((item) => {
    if (typeof item !== 'string' || item.trim().length < 1 || item.trim().length > 80) invalid();
    return item.trim();
  });
  return [...new Set(values)];
}

function parseIntegerList(value: unknown, min: number, max: number): number[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 50) invalid();
  const values = value.map((item) => parseBoundedInteger(item, min, max, ERROR_CODE));
  return [...new Set(values)];
}

function parseEnumList<const T extends readonly string[]>(
  value: unknown,
  allowed: T,
): T[number][] {
  const values = parseTextList(value);
  if (values.some((item) => !allowed.includes(item))) invalid();
  return values as T[number][];
}

function parseCursor(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string' || value.length < 8 || value.length > 500) invalid();
  return value;
}

function invalid(): never {
  throw new Error(ERROR_CODE);
}
