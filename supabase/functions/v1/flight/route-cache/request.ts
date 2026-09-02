import { isRecord } from '@shared/contracts/guards.ts';

export type RouteCacheRequest = {
  originIata: string;
  destIata?: string;
  currency?: string;
  market?: string;
  locale?: string;
};

const ALLOWED_KEYS = new Set([
  'origin',
  'originIata',
  'origin_iata',
  'destination',
  'dest',
  'destIata',
  'destinationIata',
  'destination_iata',
  'currency',
  'currencyCode',
  'currency_code',
  'market',
  'marketCode',
  'market_code',
  'locale',
]);

export function parseRouteCacheRequest(value: unknown): {
  originIata: string;
  destIata?: string;
  currency?: string;
  market?: string;
  locale?: string;
} {
  if (!isRecord(value)) {
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }

  for (const key of Object.keys(value)) {
    if (!ALLOWED_KEYS.has(key)) {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
  }

  const rawOrigin = value.originIata ?? value.origin ?? value.origin_iata;
  if (typeof rawOrigin !== 'string') {
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }
  const originIata = rawOrigin.trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(originIata)) {
    throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }

  const rawDest = value.destIata ??
    value.destinationIata ??
    value.dest ??
    value.destination ??
    value.destination_iata;
  let destIata: string | undefined = undefined;
  if (rawDest !== undefined && rawDest !== null && rawDest !== '') {
    if (typeof rawDest !== 'string') {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    const normDest = rawDest.trim().toUpperCase();
    if (!/^[A-Z]{3}$/.test(normDest) || normDest === originIata) {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    destIata = normDest;
  }

  const rawCurr = value.currency ?? value.currencyCode ?? value.currency_code;
  let currency = 'USD';
  if (rawCurr !== undefined && rawCurr !== null && rawCurr !== '') {
    if (typeof rawCurr !== 'string') {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    const normCurr = rawCurr.trim().toUpperCase();
    if (!/^[A-Z]{3}$/.test(normCurr)) {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    currency = normCurr;
  }

  const rawMarket = value.market ?? value.marketCode ?? value.market_code;
  let market = 'us';
  if (rawMarket !== undefined && rawMarket !== null && rawMarket !== '') {
    if (typeof rawMarket !== 'string') {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    const normMarket = rawMarket.trim().toLowerCase();
    if (!/^[a-z]{2}$/.test(normMarket)) {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    market = normMarket;
  }

  const rawLocale = value.locale;
  let locale: string | undefined = undefined;
  if (rawLocale !== undefined && rawLocale !== null && rawLocale !== '') {
    if (typeof rawLocale !== 'string') {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    const normLocale = rawLocale.trim();
    if (!/^[a-z]{2}(?:-[A-Za-z0-9]{2,8})?$/i.test(normLocale)) {
      throw new Error('ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
    }
    locale = normLocale;
  }

  const result: {
    originIata: string;
    destIata?: string;
    currency?: string;
    market?: string;
    locale?: string;
  } = {
    originIata,
    currency,
    market,
  };
  if (destIata) result.destIata = destIata;
  if (locale) result.locale = locale;
  return result;
}
