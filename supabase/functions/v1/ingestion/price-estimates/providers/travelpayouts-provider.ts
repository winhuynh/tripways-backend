import {
  type FlightContentProviderResult,
  parseFlightContentObservationBatch,
} from '../provider-contract.ts';

export type TravelpayoutsNormalizationContext = {
  marketCode: string;
  locale: string;
  observedAt: string;
};

export type TravelpayoutsAdapterOptions = {
  token: string;
  origins: readonly string[];
  currencyCode: string;
  marketCode: string;
  locale: string;
  endpoint?: string;
  fetcher?: typeof fetch;
  now?: () => Date;
};

export function createTravelpayoutsAdapter(options: TravelpayoutsAdapterOptions): {
  load(): Promise<FlightContentProviderResult>;
} {
  const fetcher = options.fetcher ?? fetch;
  const endpoint = options.endpoint ??
    'https://api.travelpayouts.com/aviasales/v3/prices_for_dates';
  return {
    async load(): Promise<FlightContentProviderResult> {
      const observedAt = (options.now ?? (() => new Date()))().toISOString();
      const rows: unknown[] = [];
      for (const origin of options.origins) {
        const url = new URL(endpoint);
        url.searchParams.set('origin', origin);
        url.searchParams.set('currency', options.currencyCode);
        url.searchParams.set('market', options.marketCode);
        url.searchParams.set('sorting', 'route');
        url.searchParams.set('unique', 'true');
        url.searchParams.set('limit', '1000');
        const response = await fetcher(url, {
          headers: { 'X-Access-Token': options.token, Accept: 'application/json' },
        });
        if (!response.ok) {
          return { ok: false, issues: [{ code: 'ERR_PROVIDER_UNAVAILABLE', sourceKey: origin }] };
        }
        const payload: unknown = await response.json();
        if (!isRecord(payload) || payload.success !== true || !Array.isArray(payload.data)) {
          return {
            ok: false,
            issues: [{ code: 'ERR_INVALID_PROVIDER_PAYLOAD', sourceKey: origin }],
          };
        }
        rows.push(...payload.data);
      }
      return normalizeTravelpayoutsResponse({
        success: true,
        currency: options.currencyCode,
        data: rows,
      }, { marketCode: options.marketCode, locale: options.locale, observedAt });
    },
  };
}

export function normalizeTravelpayoutsResponse(
  payload: unknown,
  context: TravelpayoutsNormalizationContext,
): FlightContentProviderResult {
  if (!isRecord(payload) || payload.success !== true || !Array.isArray(payload.data)) {
    return { ok: false, issues: [{ code: 'ERR_INVALID_PROVIDER_PAYLOAD', sourceKey: null }] };
  }
  const observedAtMs = Date.parse(context.observedAt);
  if (!Number.isFinite(observedAtMs)) {
    return { ok: false, issues: [{ code: 'ERR_INVALID_PROVIDER_PAYLOAD', sourceKey: null }] };
  }
  const currency = typeof payload.currency === 'string' ? payload.currency.toUpperCase() : null;
  const observations = payload.data.map((raw, index) =>
    normalizeRow(raw, index, currency, context)
  );
  return parseFlightContentObservationBatch({
    schemaVersion: 'flight-content-observations.v1',
    sourceTime: context.observedAt,
    observations,
  });
}

function normalizeRow(
  value: unknown,
  index: number,
  responseCurrency: string | null,
  context: TravelpayoutsNormalizationContext,
): Record<string, unknown> {
  const row = isRecord(value) ? value : {};
  const foundAt = stringValue(row.found_at) ?? context.observedAt;
  const providerExpiresAt = stringValue(row.expires_at);
  const hardLimit = Date.parse(foundAt) + 604_800_000;
  const providerLimit = providerExpiresAt === null ? hardLimit : Date.parse(providerExpiresAt);
  const validityLimit = Math.min(hardLimit, providerLimit);
  const validUntil = Number.isFinite(validityLimit) ? new Date(validityLimit).toISOString() : null;
  const originCode = upperCode(row.origin);
  const destinationCode = upperCode(row.destination);
  const transfers = integerValue(row.transfers);
  return {
    sourceId: `${originCode ?? 'unknown'}-${destinationCode ?? 'unknown'}-${
      stringValue(row.departure_at) ?? index
    }`,
    observationType: 'cached_fare',
    originCode,
    destinationCode,
    originAirportIata: upperCode(row.origin_airport) ?? originCode,
    destinationAirportIata: upperCode(row.destination_airport) ?? destinationCode,
    airlineIata: upperCode(row.airline),
    tripType: stringValue(row.return_at) ? 'return' : 'one_way',
    direct: transfers === null ? null : transfers === 0,
    transferCount: transfers,
    amount: numberValue(row.price),
    currencyCode: responseCurrency,
    marketCode: context.marketCode,
    locale: context.locale,
    departureDate: datePart(row.departure_at),
    returnDate: datePart(row.return_at),
    durationMinutes: integerValue(row.duration),
    foundAt,
    providerExpiresAt,
    validUntil,
    affiliatePath: stringValue(row.link),
  };
}
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
function stringValue(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}
function upperCode(value: unknown): string | null {
  return stringValue(value)?.toUpperCase() ?? null;
}
function numberValue(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : null;
}
function integerValue(value: unknown): number | null {
  return Number.isInteger(value) && Number(value) >= 0 ? Number(value) : null;
}
function datePart(value: unknown): string | null {
  const text = stringValue(value);
  return text && /^\d{4}-\d{2}-\d{2}/.test(text) ? text.slice(0, 10) : null;
}
