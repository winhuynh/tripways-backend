import { isRecord } from '@shared/contracts/guards.ts';

export type AirportRoutesCacheRequest = {
  originIata: string;
};

const ALLOWED_KEYS = new Set([
  'origin',
  'originIata',
  'origin_iata',
]);

export function parseAirportRoutesCacheRequest(value: unknown): AirportRoutesCacheRequest {
  if (!isRecord(value)) {
    throw new Error('ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST');
  }

  for (const key of Object.keys(value)) {
    if (!ALLOWED_KEYS.has(key)) {
      throw new Error('ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST');
    }
  }

  const rawOrigin = value.originIata ?? value.origin ?? value.origin_iata;
  if (typeof rawOrigin !== 'string') {
    throw new Error('ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST');
  }
  const originIata = rawOrigin.trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(originIata)) {
    throw new Error('ERR_AIRPORT_ROUTES_CACHE_INVALID_REQUEST');
  }

  return { originIata };
}
