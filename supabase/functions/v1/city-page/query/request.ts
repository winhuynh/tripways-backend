export const CITY_PAGE_ACTIONS = [
  'get_overview',
  'get_airports',
  'get_quick_facts',
  'get_destinations',
  'get_airlines',
  'get_insights',
  'get_internal_links',
  'get_faqs',
] as const;

export type CityPageAction = (typeof CITY_PAGE_ACTIONS)[number];

export type CityPageQueryInput = {
  city_slug: string;
  locale: string;
  origin_airports?: string[];
  airlines?: string[];
  destination_countries?: string[];
  max_duration_minutes?: number;
  departure_window?: string;
  limit?: number;
  offset?: number;
};

export type CityPageQueryRequest = {
  action: CityPageAction;
  input: CityPageQueryInput;
};

const DESTINATION_FIELDS = new Set([
  'city_slug',
  'locale',
  'origin_airports',
  'airlines',
  'destination_countries',
  'max_duration_minutes',
  'departure_window',
  'limit',
  'offset',
]);

export function parseCityPageQueryRequest(value: unknown): CityPageQueryRequest {
  if (!isRecord(value) || !isAction(value.action) || !isRecord(value.input)) invalidRequest();

  const action = value.action;
  const allowedFields = action === 'get_destinations'
    ? DESTINATION_FIELDS
    : new Set(['city_slug', 'locale']);

  for (const key of Object.keys(value.input)) {
    if (!allowedFields.has(key)) invalidRequest();
  }

  const citySlug = parseSlug(value.input.city_slug);
  const locale = parseLocale(value.input.locale);
  const input: CityPageQueryInput = { city_slug: citySlug, locale };

  if (action === 'get_destinations') {
    assignCodeList(input, 'origin_airports', value.input.origin_airports, 3);
    assignCodeList(input, 'airlines', value.input.airlines, 2);
    assignCodeList(input, 'destination_countries', value.input.destination_countries, 2);
    assignInteger(input, 'max_duration_minutes', value.input.max_duration_minutes, 1, 1440);
    assignInteger(input, 'limit', value.input.limit, 1, 100);
    assignInteger(input, 'offset', value.input.offset, 0, 10000);

    if (value.input.departure_window !== undefined) {
      const window = value.input.departure_window;
      if (
        typeof window !== 'string' ||
        !['morning', 'afternoon', 'evening', 'night'].includes(window)
      ) invalidRequest();
      input.departure_window = window;
    }
  }

  return { action, input };
}

function parseSlug(value: unknown): string {
  if (typeof value !== 'string') invalidRequest();
  const normalized = value.trim().toLowerCase();
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(normalized)) invalidRequest();
  return normalized;
}

function parseLocale(value: unknown): string {
  if (value === undefined) return 'en-GB';
  if (typeof value !== 'string' || !/^[a-z]{2}(?:-[A-Z]{2})?$/.test(value.trim())) invalidRequest();
  return value.trim();
}

function assignCodeList(
  target: CityPageQueryInput,
  key: 'origin_airports' | 'airlines' | 'destination_countries',
  value: unknown,
  length: number,
): void {
  if (value === undefined) return;
  if (!Array.isArray(value)) invalidRequest();
  const codes = value.map((item) => {
    if (typeof item !== 'string') invalidRequest();
    const code = item.trim().toUpperCase();
    if (!new RegExp(`^[A-Z0-9]{${length}}$`).test(code)) invalidRequest();
    return code;
  });
  target[key] = [...new Set(codes)];
}

function assignInteger(
  target: CityPageQueryInput,
  key: 'max_duration_minutes' | 'limit' | 'offset',
  value: unknown,
  minimum: number,
  maximum: number,
): void {
  if (value === undefined) return;
  if (!Number.isInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    invalidRequest();
  }
  target[key] = value as number;
}

function isAction(value: unknown): value is CityPageAction {
  return typeof value === 'string' && (CITY_PAGE_ACTIONS as readonly string[]).includes(value);
}

function invalidRequest(): never {
  throw new Error('ERR_CITY_PAGE_INVALID_REQUEST');
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
