export type ProviderIssueCode =
  | 'ERR_DUPLICATE_SOURCE_KEY'
  | 'ERR_INVALID_COORDINATES'
  | 'ERR_INVALID_PROVIDER_PAYLOAD'
  | 'ERR_MISSING_REQUIRED_FIELD'
  | 'ERR_PROVIDER_RECORD_LIMIT'
  | 'ERR_UNRESOLVED_REFERENCE'
  | 'ERR_UNSUPPORTED_SCHEMA_VERSION';

export type ProviderIssue = {
  code: ProviderIssueCode;
  recordType: 'batch' | 'country' | 'city' | 'airport';
  sourceKey: string | null;
};

export type CanonicalCountry = {
  iso2: string;
  iso3: string;
  name: string;
};

export type CanonicalCity = {
  sourceId: string;
  name: string;
  countryIso2: string;
  latitude: number | null;
  longitude: number | null;
};

export type CanonicalAirport = {
  sourceId: string;
  name: string;
  iata: string | null;
  icao: string | null;
  citySourceId: string | null;
  countryIso2: string;
  latitude: number | null;
  longitude: number | null;
  type: string;
};

export type CanonicalBaseDataBatch = {
  schemaVersion: 'base-data.v1';
  sourceTime: string | null;
  countries: CanonicalCountry[];
  cities: CanonicalCity[];
  airports: CanonicalAirport[];
  importMetadata?: {
    sourceUrl: string;
    sourceEtag: string | null;
    sourceChecksum: string;
    downloadedBytes: number;
    rawRecordCount: number;
    eligibleRecordCount: number;
    filteredRecordCount: number;
    invalidRecordCount: number;
    filterVersion: 'ourairports-commercial.v1';
  };
};

export type ProviderResult =
  | { ok: true; batch: CanonicalBaseDataBatch }
  | { ok: false; issues: ProviderIssue[] };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function requiredString(
  record: Record<string, unknown>,
  field: string,
  recordType: ProviderIssue['recordType'],
  sourceKey: string | null,
  issues: ProviderIssue[],
): string | null {
  const value = record[field];
  if (typeof value === 'string' && value.trim().length > 0) return value.trim();
  issues.push({ code: 'ERR_MISSING_REQUIRED_FIELD', recordType, sourceKey });
  return null;
}

function optionalString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : null;
}

function coordinates(
  record: Record<string, unknown>,
  recordType: 'city' | 'airport',
  sourceKey: string | null,
  issues: ProviderIssue[],
): [number | null, number | null] {
  const latitude = record.latitude;
  const longitude = record.longitude;
  if (latitude == null && longitude == null) return [null, null];
  if (
    typeof latitude !== 'number' ||
    typeof longitude !== 'number' ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    issues.push({ code: 'ERR_INVALID_COORDINATES', recordType, sourceKey });
    return [null, null];
  }
  return [latitude, longitude];
}

function arrayField(payload: Record<string, unknown>, field: string): unknown[] | null {
  const value = payload[field];
  return Array.isArray(value) ? value : null;
}

export function parseCanonicalBaseDataBatch(payload: unknown): ProviderResult {
  if (!isRecord(payload)) {
    return {
      ok: false,
      issues: [{ code: 'ERR_INVALID_PROVIDER_PAYLOAD', recordType: 'batch', sourceKey: null }],
    };
  }
  if (payload.schemaVersion !== 'base-data.v1') {
    return {
      ok: false,
      issues: [{ code: 'ERR_UNSUPPORTED_SCHEMA_VERSION', recordType: 'batch', sourceKey: null }],
    };
  }

  const rawCountries = arrayField(payload, 'countries');
  const rawCities = arrayField(payload, 'cities');
  const rawAirports = arrayField(payload, 'airports');
  if (!rawCountries || !rawCities || !rawAirports) {
    return {
      ok: false,
      issues: [{ code: 'ERR_INVALID_PROVIDER_PAYLOAD', recordType: 'batch', sourceKey: null }],
    };
  }

  const issues: ProviderIssue[] = [];
  const countries: CanonicalCountry[] = [];
  const cities: CanonicalCity[] = [];
  const airports: CanonicalAirport[] = [];
  const countryKeys = new Set<string>();
  const cityKeys = new Set<string>();
  const airportKeys = new Set<string>();

  for (const raw of rawCountries) {
    if (!isRecord(raw)) {
      issues.push({ code: 'ERR_INVALID_PROVIDER_PAYLOAD', recordType: 'country', sourceKey: null });
      continue;
    }
    const iso2 = requiredString(raw, 'iso2', 'country', null, issues);
    const iso3 = requiredString(raw, 'iso3', 'country', iso2, issues);
    const name = requiredString(raw, 'name', 'country', iso2, issues);
    if (!iso2 || !iso3 || !name) continue;
    if (countryKeys.has(iso2)) {
      issues.push({ code: 'ERR_DUPLICATE_SOURCE_KEY', recordType: 'country', sourceKey: iso2 });
      continue;
    }
    countryKeys.add(iso2);
    countries.push({ iso2: iso2.toUpperCase(), iso3: iso3.toUpperCase(), name });
  }

  for (const raw of rawCities) {
    if (!isRecord(raw)) {
      issues.push({ code: 'ERR_INVALID_PROVIDER_PAYLOAD', recordType: 'city', sourceKey: null });
      continue;
    }
    const sourceId = requiredString(raw, 'sourceId', 'city', null, issues);
    const name = requiredString(raw, 'name', 'city', sourceId, issues);
    const countryIso2 = requiredString(raw, 'countryIso2', 'city', sourceId, issues);
    const [latitude, longitude] = coordinates(raw, 'city', sourceId, issues);
    if (!sourceId || !name || !countryIso2) continue;
    if (cityKeys.has(sourceId)) {
      issues.push({ code: 'ERR_DUPLICATE_SOURCE_KEY', recordType: 'city', sourceKey: sourceId });
      continue;
    }
    cityKeys.add(sourceId);
    cities.push({ sourceId, name, countryIso2: countryIso2.toUpperCase(), latitude, longitude });
  }

  for (const raw of rawAirports) {
    if (!isRecord(raw)) {
      issues.push({ code: 'ERR_INVALID_PROVIDER_PAYLOAD', recordType: 'airport', sourceKey: null });
      continue;
    }
    const sourceId = requiredString(raw, 'sourceId', 'airport', null, issues);
    const name = requiredString(raw, 'name', 'airport', sourceId, issues);
    const countryIso2 = requiredString(raw, 'countryIso2', 'airport', sourceId, issues);
    const type = requiredString(raw, 'type', 'airport', sourceId, issues);
    const [latitude, longitude] = coordinates(raw, 'airport', sourceId, issues);
    if (!sourceId || !name || !countryIso2 || !type) continue;
    if (airportKeys.has(sourceId)) {
      issues.push({ code: 'ERR_DUPLICATE_SOURCE_KEY', recordType: 'airport', sourceKey: sourceId });
      continue;
    }
    airportKeys.add(sourceId);
    airports.push({
      sourceId,
      name,
      iata: optionalString(raw.iata)?.toUpperCase() ?? null,
      icao: optionalString(raw.icao)?.toUpperCase() ?? null,
      citySourceId: optionalString(raw.citySourceId),
      countryIso2: countryIso2.toUpperCase(),
      latitude,
      longitude,
      type,
    });
  }

  for (const city of cities) {
    if (!countryKeys.has(city.countryIso2)) {
      issues.push({
        code: 'ERR_UNRESOLVED_REFERENCE',
        recordType: 'city',
        sourceKey: city.sourceId,
      });
    }
  }
  for (const airport of airports) {
    if (
      !countryKeys.has(airport.countryIso2) ||
      (airport.citySourceId !== null && !cityKeys.has(airport.citySourceId))
    ) {
      issues.push({
        code: 'ERR_UNRESOLVED_REFERENCE',
        recordType: 'airport',
        sourceKey: airport.sourceId,
      });
    }
  }

  if (issues.length > 0) return { ok: false, issues };
  return {
    ok: true,
    batch: {
      schemaVersion: 'base-data.v1',
      sourceTime: optionalString(payload.sourceTime),
      countries,
      cities,
      airports,
    },
  };
}
