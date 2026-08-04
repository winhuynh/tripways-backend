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
  'max_duration_minutes',
  'max_layover_minutes',
  'cabin',
  'price_max',
  'currency',
]);

export type RouteSearchScope =
  | { type: 'global' }
  | { type: 'origin_city'; key: string }
  | { type: 'origin_airport'; key: string }
  | { type: 'city_pair'; from: string; to: string };

export type RouteSearchFilters = {
  maxStops: 0 | 1 | 2 | 3;
  airlines: string[];
  connectionAirports: string[];
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
  const cabin = filters.cabin ?? 'any';
  if (!['any', 'economy', 'premium_economy', 'business', 'first'].includes(String(cabin))) {
    invalid();
  }
  const priceMax = filters.price_max === undefined
    ? null
    : parseNonNegativeNumber(filters.price_max, ERROR_CODE);
  const currency = filters.currency === undefined
    ? null
    : parseCode(filters.currency, 3, ERROR_CODE);
  if ((priceMax === null) !== (currency === null)) invalid();
  return {
    scope: parseScope(value.scope),
    filters: {
      maxStops: parseBoundedInteger(filters.max_stops ?? 3, 0, 3, ERROR_CODE) as 0 | 1 | 2 | 3,
      airlines: parseCodeList(filters.airlines, 2, ERROR_CODE),
      connectionAirports: parseCodeList(filters.connection_airports, 3, ERROR_CODE),
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
  if (value.type === 'city_pair' && Object.keys(value).length === 3) {
    const from = parseSlug(value.from, ERROR_CODE);
    const to = parseSlug(value.to, ERROR_CODE);
    if (from === to) invalid();
    return { type: 'city_pair', from, to };
  }
  invalid();
}

function optionalPositiveInteger(value: unknown): number | null {
  return value === undefined ? null : parseBoundedInteger(value, 1, 10080, ERROR_CODE);
}

function parseCursor(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string' || value.length < 8 || value.length > 500) invalid();
  return value;
}

function invalid(): never {
  throw new Error(ERROR_CODE);
}
