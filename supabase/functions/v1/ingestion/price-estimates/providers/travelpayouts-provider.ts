export interface NormalizedPriceObservation {
  originIata: string;
  destinationIata: string;
  providerAirlineIata: string | null;
  observedAmount: number | null;
  currencyCode: string | null;
  departureDate: string | null;
  returnDate: string | null;
  direct: boolean | null;
  transferCount: number | null;
  durationMinutes: number | null;
  foundAt: string;
  validUntil: string;
  affiliatePath: string | null;
}

export interface TravelpayoutsConfig {
  apiToken?: string;
  token?: string;
  baseUrl?: string;
  fetchFn?: typeof fetch;
  timeoutMs?: number;
}

export interface TravelpayoutsFetchParams {
  originIata: string;
  destIata?: string;
  currency?: string;
  market?: string;
  locale?: string;
}

const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000; // 604,800,000 ms

function extractItems(payload: unknown): Record<string, unknown>[] {
  if (!payload || typeof payload !== 'object') {
    return [];
  }
  if (Array.isArray(payload)) {
    return payload.filter((x): x is Record<string, unknown> => typeof x === 'object' && x !== null);
  }
  const obj = payload as Record<string, unknown>;
  if (Array.isArray(obj.data)) {
    return obj.data.filter((x): x is Record<string, unknown> =>
      typeof x === 'object' && x !== null
    );
  }
  if (obj.data && typeof obj.data === 'object') {
    return Object.values(obj.data).filter(
      (x): x is Record<string, unknown> => typeof x === 'object' && x !== null,
    );
  }
  if (Array.isArray(obj.prices)) {
    return obj.prices.filter((x): x is Record<string, unknown> =>
      typeof x === 'object' && x !== null
    );
  }
  return [];
}

function parseIsoDate(val: unknown): string | null {
  if (typeof val !== 'string' || !val.trim()) return null;
  const trimmed = val.trim();
  const candidate = trimmed.slice(0, 10);
  if (/^\d{4}-\d{2}-\d{2}$/.test(candidate)) {
    const parsed = Date.parse(candidate);
    if (Number.isFinite(parsed)) {
      return candidate;
    }
  }
  return null;
}

function parseDurationMinutes(val: unknown): number | null {
  if (typeof val === 'number' && Number.isFinite(val) && val > 0) {
    return Math.round(val);
  }
  if (typeof val === 'string' && val.trim()) {
    const trimmed = val.trim();
    const isoMatch = trimmed.toUpperCase().match(/^PT(?:(\d+)H)?(?:(\d+)M)?$/);
    if (isoMatch) {
      const hours = parseInt(isoMatch[1] || '0', 10);
      const minutes = parseInt(isoMatch[2] || '0', 10);
      const total = hours * 60 + minutes;
      return total > 0 ? total : null;
    }
    const num = parseInt(trimmed, 10);
    if (Number.isFinite(num) && num > 0) {
      return num;
    }
  }
  return null;
}

function parseAffiliatePath(link: unknown): string | null {
  if (typeof link !== 'string' || !link.trim()) {
    return null;
  }
  const trimmed = link.trim();
  if (trimmed.startsWith('//')) {
    return null;
  }
  if (trimmed.startsWith('/')) {
    return trimmed;
  }
  try {
    const parsed = new URL(trimmed);
    const pathAndQuery = `${parsed.pathname}${parsed.search}`;
    if (pathAndQuery.startsWith('/') && !pathAndQuery.startsWith('//')) {
      return pathAndQuery;
    }
  } catch {
    // Malformed or unsupported URL
  }
  return null;
}

export function parseTravelpayoutsFareObservations(
  originIata: string,
  payload: unknown,
  defaultCurrency?: string,
  _defaultMarket?: string,
): NormalizedPriceObservation[] {
  const normOrigin = (originIata || '').trim().toUpperCase();
  if (!normOrigin || normOrigin.length !== 3 || !/^[A-Z0-9]{3}$/.test(normOrigin)) {
    return [];
  }

  const items = extractItems(payload);
  if (!items.length) {
    return [];
  }

  const observations: NormalizedPriceObservation[] = [];

  for (const item of items) {
    if (!item || typeof item !== 'object') continue;

    const rawDest = item.destination_airport ?? item.destination ?? item.destinationIata ??
      item.dest;
    const destIata = typeof rawDest === 'string' ? rawDest.trim().toUpperCase() : '';
    if (
      !destIata ||
      destIata.length !== 3 ||
      destIata === normOrigin ||
      !/^[A-Z0-9]{3}$/.test(destIata)
    ) {
      continue;
    }

    const rawOrigin = item.origin_airport ?? item.origin ?? item.originIata;
    const itemOrigin = typeof rawOrigin === 'string' &&
        /^[A-Z0-9]{3}$/.test(rawOrigin.trim().toUpperCase())
      ? rawOrigin.trim().toUpperCase()
      : normOrigin;

    // Airline code
    const rawAirline = item.airline ?? item.airline_iata ?? item.airline_code ??
      item.providerAirlineIata;
    const airlineStr = typeof rawAirline === 'string' ? rawAirline.trim().toUpperCase() : '';
    const providerAirlineIata = airlineStr && /^[A-Z0-9]{2,3}$/.test(airlineStr)
      ? airlineStr
      : null;

    // Amount & Currency
    let observedAmount: number | null = null;
    const rawPrice = item.price ?? item.value ?? item.amount ?? item.observedAmount;
    if (typeof rawPrice === 'number' && Number.isFinite(rawPrice) && rawPrice >= 0) {
      observedAmount = Math.round(rawPrice * 100) / 100;
    } else if (typeof rawPrice === 'string' && rawPrice.trim()) {
      const parsed = parseFloat(rawPrice.trim());
      if (Number.isFinite(parsed) && parsed >= 0) {
        observedAmount = Math.round(parsed * 100) / 100;
      }
    }

    let currencyCode: string | null = null;
    if (observedAmount !== null) {
      const payloadObj = typeof payload === 'object' && payload !== null
        ? (payload as Record<string, unknown>)
        : null;
      const rawCurr = item.currency ?? item.currency_code ?? item.currencyCode ??
        payloadObj?.currency ?? defaultCurrency ?? 'USD';
      if (typeof rawCurr === 'string' && /^[A-Za-z]{3}$/.test(rawCurr.trim())) {
        currencyCode = rawCurr.trim().toUpperCase();
      } else {
        currencyCode = 'USD';
      }
    }

    // Departure & Return dates
    const departureDate = parseIsoDate(
      item.departure_at ?? item.departure_date ?? item.depart_date ?? item.departureDate,
    );
    let returnDate = parseIsoDate(item.return_at ?? item.return_date ?? item.returnDate);
    if (departureDate && returnDate && returnDate < departureDate) {
      returnDate = null;
    }

    // Direct & transfer count
    let direct: boolean | null = null;
    let transferCount: number | null = null;
    const rawTransfers = item.transfers ?? item.transfer_count ?? item.transferCount ??
      item.number_of_changes ?? item.stops;

    if (typeof rawTransfers === 'number' && Number.isInteger(rawTransfers) && rawTransfers >= 0) {
      transferCount = rawTransfers;
      direct = rawTransfers === 0;
    } else if (typeof rawTransfers === 'string' && /^\d+$/.test(rawTransfers.trim())) {
      const parsed = parseInt(rawTransfers.trim(), 10);
      transferCount = parsed;
      direct = parsed === 0;
    } else if (typeof item.direct === 'boolean') {
      direct = item.direct;
      transferCount = item.direct ? 0 : 1;
    }

    const durationMinutes = parseDurationMinutes(
      item.duration ?? item.duration_to ?? item.flight_duration ??
        item.flightDurationMinutes ?? item.durationMinutes,
    );

    // Timestamps & 7-day TTL capping
    const rawFoundAt = item.found_at ?? item.observed_at ?? item.created_at ?? item.foundAt;
    let foundAtMs = Date.now();
    if (typeof rawFoundAt === 'string' && rawFoundAt.trim()) {
      const parsed = Date.parse(rawFoundAt.trim());
      if (Number.isFinite(parsed) && parsed > 0) {
        foundAtMs = parsed;
      }
    }
    const foundAt = new Date(foundAtMs).toISOString();

    const maxValidUntilMs = foundAtMs + SEVEN_DAYS_MS;
    let validUntilMs = maxValidUntilMs;
    const rawExpiry = item.valid_until ?? item.expires_at ?? item.provider_expires_at ??
      item.validUntil;
    if (typeof rawExpiry === 'string' && rawExpiry.trim()) {
      const parsedExpiry = Date.parse(rawExpiry.trim());
      if (Number.isFinite(parsedExpiry) && parsedExpiry > foundAtMs) {
        validUntilMs = Math.min(parsedExpiry, maxValidUntilMs);
      }
    }
    const validUntil = new Date(validUntilMs).toISOString();

    const affiliatePath = parseAffiliatePath(
      item.link ?? item.affiliate_path ?? item.affiliatePath ?? item.search_url,
    );

    observations.push({
      originIata: itemOrigin,
      destinationIata: destIata,
      providerAirlineIata,
      observedAmount,
      currencyCode,
      departureDate,
      returnDate,
      direct,
      transferCount,
      durationMinutes,
      foundAt,
      validUntil,
      affiliatePath,
    });
  }

  return observations;
}

export async function fetchRoutePricesFromTravelpayouts(
  config: TravelpayoutsConfig,
  params: TravelpayoutsFetchParams,
): Promise<NormalizedPriceObservation[]> {
  const normOrigin = (params.originIata || '').trim().toUpperCase();
  if (!normOrigin || normOrigin.length !== 3 || !/^[A-Z0-9]{3}$/.test(normOrigin)) {
    throw new Error('ERR_INVALID_IATA_CODE');
  }

  const token = (config.apiToken || config.token || '').trim();
  if (!token) {
    throw new Error('ERR_MISSING_API_TOKEN');
  }

  const baseUrl = (config.baseUrl || 'https://api.travelpayouts.com/aviasales/v3/prices_for_dates')
    .replace(/\/+$/, '');
  const url = new URL(baseUrl);
  url.searchParams.set('origin', normOrigin);

  if (params.destIata) {
    const normDest = params.destIata.trim().toUpperCase();
    if (normDest && normDest.length === 3 && normDest !== normOrigin) {
      url.searchParams.set('destination', normDest);
    }
  }

  if (params.currency && params.currency.trim()) {
    url.searchParams.set('currency', params.currency.trim().toLowerCase());
  }
  if (params.market && params.market.trim()) {
    url.searchParams.set('market', params.market.trim().toLowerCase());
  }
  if (params.locale && params.locale.trim()) {
    url.searchParams.set('locale', params.locale.trim().toLowerCase());
  }
  url.searchParams.set('unique', 'false');
  url.searchParams.set('sorting', 'price');

  const timeoutMs = config.timeoutMs ?? 8000;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  const fetcher = config.fetchFn || fetch;
  const headers: Record<string, string> = {
    'Accept': 'application/json',
    'x-access-token': token,
  };

  try {
    const response = await fetcher(url.toString(), {
      method: 'GET',
      headers,
      signal: controller.signal,
    });

    if (response.status === 404) {
      return [];
    }

    if (response.status === 429) {
      throw new Error('ERR_PROVIDER_RATE_LIMITED');
    }

    if (response.status === 401 || response.status === 403) {
      throw new Error('ERR_PROVIDER_UNAUTHORIZED');
    }

    if (!response.ok) {
      throw new Error(`Travelpayouts API HTTP ${response.status}`);
    }

    const json = await response.json();
    return parseTravelpayoutsFareObservations(
      normOrigin,
      json,
      params.currency,
      params.market,
    );
  } catch (error) {
    if (
      (error instanceof DOMException && error.name === 'AbortError') ||
      (error instanceof Error &&
        (error.name === 'AbortError' || error.name === 'TimeoutError' ||
          error.message.includes('abort') || error.message.includes('timeout')))
    ) {
      throw new Error(`Travelpayouts API request timed out after ${timeoutMs}ms`);
    }
    if (error instanceof Error) {
      if (token && error.message.includes(token)) {
        throw new Error(error.message.replaceAll(token, '[redacted]'));
      }
      throw error;
    }
    throw new Error('ERR_PROVIDER_UNAVAILABLE');
  } finally {
    clearTimeout(timeoutId);
  }
}
