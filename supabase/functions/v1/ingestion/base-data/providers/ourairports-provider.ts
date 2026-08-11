import type { CanonicalAirport, ProviderIssue, ProviderResult } from '../provider-contract.ts';

const FILTER_VERSION = 'ourairports-commercial.v1' as const;
const REQUIRED_HEADERS = [
  'id',
  'ident',
  'type',
  'name',
  'latitude_deg',
  'longitude_deg',
  'iso_country',
  'iso_region',
  'municipality',
  'scheduled_service',
  'icao_code',
  'iata_code',
] as const;
const ELIGIBLE_TYPES = new Set(['large_airport', 'medium_airport']);

export type OurAirportsMetrics = {
  rawRecordCount: number;
  eligibleRecordCount: number;
  filteredRecordCount: number;
  invalidRecordCount: number;
};

export type OurAirportsParseResult =
  | { ok: true; airports: CanonicalAirport[]; metrics: OurAirportsMetrics }
  | { ok: false; issues: ProviderIssue[] };

export type OurAirportsProviderConfig = {
  airportsUrl: string;
  denylist: ReadonlySet<string>;
  maxDownloadBytes: number;
  fetcher?: typeof fetch;
};

export async function loadOurAirportsProvider(
  config: OurAirportsProviderConfig,
): Promise<ProviderResult> {
  const url = safeHttpsUrl(config.airportsUrl);
  if (
    !url || !Number.isInteger(config.maxDownloadBytes) || config.maxDownloadBytes < 1
  ) {
    return batchIssue('ERR_INVALID_PROVIDER_PAYLOAD');
  }

  let response: Response;
  try {
    response = await (config.fetcher ?? fetch)(url, {
      headers: { accept: 'text/csv' },
      redirect: 'error',
    });
  } catch {
    return batchIssue('ERR_INVALID_PROVIDER_PAYLOAD');
  }
  if (!response.ok) return batchIssue('ERR_INVALID_PROVIDER_PAYLOAD');

  const contentLength = Number(response.headers.get('content-length'));
  if (Number.isFinite(contentLength) && contentLength > config.maxDownloadBytes) {
    return batchIssue('ERR_PROVIDER_RECORD_LIMIT');
  }

  const csv = await response.text();
  const downloadedBytes = new TextEncoder().encode(csv).byteLength;
  if (downloadedBytes > config.maxDownloadBytes) {
    return batchIssue('ERR_PROVIDER_RECORD_LIMIT');
  }

  const parsed = parseOurAirportsCsv(csv, config.denylist);
  if (!parsed.ok) return parsed;
  const sourceChecksum = await sha256(csv);

  const lastModified = response.headers.get('last-modified');
  const sourceTime = lastModified && !Number.isNaN(Date.parse(lastModified))
    ? new Date(lastModified).toISOString()
    : null;

  return {
    ok: true,
    batch: {
      schemaVersion: 'base-data.v1',
      sourceTime,
      countries: [],
      cities: [],
      airports: parsed.airports,
      importMetadata: {
        sourceUrl: url.toString(),
        sourceEtag: response.headers.get('etag'),
        sourceChecksum,
        downloadedBytes,
        ...parsed.metrics,
        filterVersion: FILTER_VERSION,
      },
    },
  };
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export function parseOurAirportsCsv(
  csv: string,
  denylist: ReadonlySet<string>,
): OurAirportsParseResult {
  const rows = parseCsvRows(csv);
  const header = rows[0];
  if (!header) return batchIssue('ERR_UNSUPPORTED_SCHEMA_VERSION');

  const indexes = new Map(header.map((name, index) => [name.replace(/^\uFEFF/, ''), index]));
  if (REQUIRED_HEADERS.some((name) => !indexes.has(name))) {
    return batchIssue('ERR_UNSUPPORTED_SCHEMA_VERSION');
  }

  const airports: CanonicalAirport[] = [];
  const issues: ProviderIssue[] = [];
  const seenSourceIds = new Set<string>();
  const seenIata = new Set<string>();
  let filteredRecordCount = 0;
  let invalidRecordCount = 0;

  const value = (row: string[], name: typeof REQUIRED_HEADERS[number]): string =>
    row[indexes.get(name) ?? -1]?.trim() ?? '';

  for (const row of rows.slice(1)) {
    if (row.length === 1 && row[0]?.trim() === '') continue;
    const type = value(row, 'type');
    const iata = value(row, 'iata_code').toUpperCase();
    const scheduledService = value(row, 'scheduled_service').toLowerCase();
    if (
      scheduledService !== 'yes' || !ELIGIBLE_TYPES.has(type) ||
      !/^[A-Z]{3}$/.test(iata) || denylist.has(iata)
    ) {
      filteredRecordCount += 1;
      continue;
    }

    const sourceId = value(row, 'id');
    const name = value(row, 'name');
    const countryIso2 = value(row, 'iso_country').toUpperCase();
    const latitude = Number(value(row, 'latitude_deg'));
    const longitude = Number(value(row, 'longitude_deg'));
    if (
      !/^\d+$/.test(sourceId) || name.length === 0 || !/^[A-Z]{2}$/.test(countryIso2) ||
      !Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180
    ) {
      invalidRecordCount += 1;
      issues.push({
        code: 'ERR_INVALID_PROVIDER_PAYLOAD',
        recordType: 'airport',
        sourceKey: sourceId,
      });
      continue;
    }
    if (seenSourceIds.has(sourceId) || seenIata.has(iata)) {
      issues.push({ code: 'ERR_DUPLICATE_SOURCE_KEY', recordType: 'airport', sourceKey: sourceId });
      continue;
    }
    seenSourceIds.add(sourceId);
    seenIata.add(iata);
    const icao = value(row, 'icao_code').toUpperCase();
    airports.push({
      sourceId,
      name,
      iata,
      icao: /^[A-Z0-9]{4}$/.test(icao) ? icao : null,
      citySourceId: null,
      countryIso2,
      latitude,
      longitude,
      type,
    });
  }

  if (issues.length > 0) return { ok: false, issues };
  return {
    ok: true,
    airports,
    metrics: {
      rawRecordCount:
        rows.slice(1).filter((row) => !(row.length === 1 && row[0]?.trim() === '')).length,
      eligibleRecordCount: airports.length,
      filteredRecordCount,
      invalidRecordCount,
    },
  };
}

export function parseCsvRows(csv: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let index = 0; index < csv.length; index += 1) {
    const character = csv[index];
    if (quoted) {
      if (character === '"' && csv[index + 1] === '"') {
        field += '"';
        index += 1;
      } else if (character === '"') {
        quoted = false;
      } else {
        field += character;
      }
    } else if (character === '"' && field.length === 0) {
      quoted = true;
    } else if (character === ',') {
      row.push(field);
      field = '';
    } else if (character === '\n') {
      row.push(field.replace(/\r$/, ''));
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += character;
    }
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field.replace(/\r$/, ''));
    rows.push(row);
  }
  return rows;
}

function safeHttpsUrl(value: string): URL | null {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? url : null;
  } catch {
    return null;
  }
}

function batchIssue(code: ProviderIssue['code']): { ok: false; issues: ProviderIssue[] } {
  return { ok: false, issues: [{ code, recordType: 'batch', sourceKey: null }] };
}
