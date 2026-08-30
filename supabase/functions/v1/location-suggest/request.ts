import { isRecord } from '@shared/contracts/guards.ts';

export type LocationSuggestRequest = Readonly<{
  query?: string;
  origin_iata?: string;
  radius_km?: number;
  limit?: number;
}>;

export function parseLocationSuggestRequest(payload: unknown): LocationSuggestRequest {
  if (!isRecord(payload)) {
    throw new Error('ERR_LOCATION_SUGGEST_INVALID_REQUEST');
  }

  const query = typeof payload.query === 'string' ? payload.query.trim() : undefined;
  const origin_iata = typeof payload.origin_iata === 'string'
    ? payload.origin_iata.trim().toUpperCase()
    : undefined;
  const radius_km = typeof payload.radius_km === 'number' && Number.isFinite(payload.radius_km)
    ? payload.radius_km
    : undefined;
  const limit = typeof payload.limit === 'number' && Number.isInteger(payload.limit)
    ? payload.limit
    : undefined;

  if (origin_iata !== undefined && !/^[A-Z]{3}$/.test(origin_iata)) {
    throw new Error('ERR_LOCATION_SUGGEST_INVALID_REQUEST');
  }

  return {
    query,
    origin_iata,
    radius_km,
    limit,
  };
}
