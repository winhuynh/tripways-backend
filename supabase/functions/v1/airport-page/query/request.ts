export type AirportPageAction = 'get_page' | 'search_routes';

export type AirportPageQueryInput = {
  airport_iata: string;
  locale: string;
  direction?: 'outbound' | 'inbound';
  airlines?: string[];
  countries?: string[];
  max_duration_minutes?: number;
  limit?: number;
  offset?: number;
};

export type AirportPageQueryRequest = {
  action: AirportPageAction;
  input: AirportPageQueryInput;
};

export function parseAirportPageQueryRequest(value: unknown): AirportPageQueryRequest {
  if (!isRecord(value) || !isRecord(value.input)) invalid();
  if (value.action !== 'get_page' && value.action !== 'search_routes') invalid();
  const action = value.action;
  const allowed = action === 'get_page' ? new Set(['airport_iata', 'locale']) : new Set([
    'airport_iata',
    'locale',
    'direction',
    'airlines',
    'countries',
    'max_duration_minutes',
    'limit',
    'offset',
  ]);
  if (Object.keys(value.input).some((key) => !allowed.has(key))) invalid();

  const airportIata = code(value.input.airport_iata, 3);
  const locale = value.input.locale === undefined ? 'en-GB' : value.input.locale;
  if (typeof locale !== 'string' || !/^[a-z]{2}(?:-[A-Z]{2})?$/.test(locale)) invalid();
  const input: AirportPageQueryInput = { airport_iata: airportIata, locale };
  if (action === 'search_routes') {
    if (value.input.direction !== 'outbound' && value.input.direction !== 'inbound') invalid();
    input.direction = value.input.direction;
    input.airlines = codeList(value.input.airlines, 2);
    input.countries = codeList(value.input.countries, 2);
    assignInteger(input, 'max_duration_minutes', value.input.max_duration_minutes, 1, 1440);
    assignInteger(input, 'limit', value.input.limit, 1, 100);
    assignInteger(input, 'offset', value.input.offset, 0, 10_000);
  }
  return { action, input };
}

function code(value: unknown, length: number): string {
  if (typeof value !== 'string') invalid();
  const normalized = value.trim().toUpperCase();
  if (!new RegExp(`^[A-Z0-9]{${length}}$`).test(normalized)) invalid();
  return normalized;
}

function codeList(value: unknown, length: number): string[] | undefined {
  if (value === undefined) return undefined;
  if (!Array.isArray(value)) invalid();
  return [...new Set(value.map((entry) => code(entry, length)))];
}

function assignInteger(
  target: AirportPageQueryInput,
  key: 'max_duration_minutes' | 'limit' | 'offset',
  value: unknown,
  minimum: number,
  maximum: number,
): void {
  if (value === undefined) return;
  if (!Number.isInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    invalid();
  }
  target[key] = value as number;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function invalid(): never {
  throw new Error('ERR_AIRPORT_PAGE_INVALID_REQUEST');
}
