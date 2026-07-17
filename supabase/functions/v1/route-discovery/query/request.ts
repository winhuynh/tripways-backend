export type RouteSearchInput = Record<string, unknown>;

const ALLOWED_FIELDS = new Set([
  'from',
  'to',
  'max_stops',
  'airlines',
  'exclude_airports',
  'max_duration_minutes',
  'max_layover_minutes',
  'departure_window',
  'limit',
  'offset',
]);

const NUMBER_FIELDS = new Set([
  'max_stops',
  'max_duration_minutes',
  'max_layover_minutes',
  'limit',
  'offset',
]);

export function parseRouteSearchRequest(value: unknown): RouteSearchInput {
  if (!isRecord(value)) throw new Error('ERR_ROUTE_SEARCH_REQUEST_INVALID');

  for (const [key, fieldValue] of Object.entries(value)) {
    if (!ALLOWED_FIELDS.has(key)) throw new Error('ERR_ROUTE_SEARCH_REQUEST_INVALID');
    if (NUMBER_FIELDS.has(key) && typeof fieldValue !== 'number') {
      throw new Error('ERR_ROUTE_SEARCH_REQUEST_INVALID');
    }
  }

  if (typeof value.from !== 'string' || typeof value.to !== 'string') {
    throw new Error('ERR_ROUTE_SEARCH_REQUEST_INVALID');
  }
  if ('departure_window' in value && typeof value.departure_window !== 'string') {
    throw new Error('ERR_ROUTE_SEARCH_REQUEST_INVALID');
  }
  for (const arrayField of ['airlines', 'exclude_airports'] as const) {
    if (
      arrayField in value &&
      (!Array.isArray(value[arrayField]) ||
        !value[arrayField].every((item) => typeof item === 'string'))
    ) {
      throw new Error('ERR_ROUTE_SEARCH_REQUEST_INVALID');
    }
  }

  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
