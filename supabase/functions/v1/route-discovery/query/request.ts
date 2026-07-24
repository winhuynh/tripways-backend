export type RouteSearchInput = {
  from: string;
  to: string;
  max_stops?: 0 | 1;
  airlines?: string[];
  exclude_airports?: string[];
  max_duration_minutes?: number;
  max_layover_minutes?: number;
  departure_window?: string;
  limit: number;
  offset: number;
};

export type RouteSearchRequest = {
  action: 'search_routes';
  input: RouteSearchInput;
};

const ALLOWED_INPUT_FIELDS = new Set([
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

export function parseRouteSearchRequest(value: unknown): RouteSearchRequest {
  if (!isRecord(value) || value.action !== 'search_routes' || !isRecord(value.input)) {
    invalidRequest();
  }

  const input = value.input;
  for (const key of Object.keys(input)) {
    if (!ALLOWED_INPUT_FIELDS.has(key)) invalidRequest();
  }

  const from = parseCode(input.from, 3);
  const to = parseCode(input.to, 3);
  if (from === to) invalidRequest();

  const maxStops = optionalInteger(input.max_stops, 0, 1) as 0 | 1 | undefined;
  const limit = optionalInteger(input.limit, 1, 100) ?? 20;
  const offset = optionalInteger(input.offset, 0, Number.MAX_SAFE_INTEGER) ?? 0;

  const parsed: RouteSearchInput = { from, to, limit, offset };
  if (maxStops !== undefined) parsed.max_stops = maxStops;
  assignCodeList(parsed, 'airlines', input.airlines, 2);
  assignCodeList(parsed, 'exclude_airports', input.exclude_airports, 3);
  assignOptionalPositiveInteger(parsed, 'max_duration_minutes', input.max_duration_minutes);
  assignOptionalPositiveInteger(parsed, 'max_layover_minutes', input.max_layover_minutes);
  if (input.departure_window !== undefined) {
    if (typeof input.departure_window !== 'string' || input.departure_window.length === 0) {
      invalidRequest();
    }
    parsed.departure_window = input.departure_window;
  }

  return { action: 'search_routes', input: parsed };
}

function assignCodeList(
  target: RouteSearchInput,
  key: 'airlines' | 'exclude_airports',
  value: unknown,
  length: number,
): void {
  if (value === undefined) return;
  if (!Array.isArray(value)) invalidRequest();
  target[key] = [...new Set(value.map((item) => parseCode(item, length)))];
}

function assignOptionalPositiveInteger(
  target: RouteSearchInput,
  key: 'max_duration_minutes' | 'max_layover_minutes',
  value: unknown,
): void {
  const parsed = optionalInteger(value, 1, Number.MAX_SAFE_INTEGER);
  if (parsed !== undefined) target[key] = parsed;
}

function parseCode(value: unknown, length: number): string {
  if (typeof value !== 'string') invalidRequest();
  const normalized = value.trim().toUpperCase();
  if (!new RegExp(`^[A-Z0-9]{${length}}$`).test(normalized)) invalidRequest();
  return normalized;
}

function optionalInteger(
  value: unknown,
  minimum: number,
  maximum: number,
): number | undefined {
  if (value === undefined) return undefined;
  if (!Number.isInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    invalidRequest();
  }
  return value as number;
}

function invalidRequest(): never {
  throw new Error('ERR_ROUTE_DISCOVERY_INVALID_REQUEST');
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
