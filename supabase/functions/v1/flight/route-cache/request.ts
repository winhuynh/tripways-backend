export type RouteCacheRequest = {
  origin: string;
  destination: string | null;
  currency: string;
  market: string;
  locale: string;
};

export function parseRouteCacheRequest(value: unknown): RouteCacheRequest {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }
  const input = value as Record<string, unknown>;
  const allowed = new Set(['origin', 'destination', 'currency', 'market', 'locale']);
  if (Object.keys(input).some((key) => !allowed.has(key))) {
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }
  const origin = upperCode(input.origin, 3);
  const destination = input.destination === undefined || input.destination === null
    ? null
    : upperCode(input.destination, 3);
  const currency = upperCode(input.currency, 3);
  const market = lowerCode(input.market, 2);
  const locale = typeof input.locale === 'string' && /^[a-z]{2}(?:-[A-Z]{2})?$/.test(input.locale)
    ? input.locale
    : null;
  if (!origin || !currency || !market || !locale || destination === origin) {
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }
  return { origin, destination, currency, market, locale };
}

function upperCode(value: unknown, length: number): string | null {
  if (typeof value !== 'string') return null;
  const code = value.trim().toUpperCase();
  return new RegExp(`^[A-Z0-9]{${length}}$`).test(code) ? code : null;
}

function lowerCode(value: unknown, length: number): string | null {
  if (typeof value !== 'string') return null;
  const code = value.trim().toLowerCase();
  return new RegExp(`^[a-z]{${length}}$`).test(code) ? code : null;
}
