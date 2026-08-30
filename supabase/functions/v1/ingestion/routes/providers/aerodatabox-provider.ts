export interface AeroDataBoxRoute {
  origin_iata: string;
  destination_iata: string;
  airline_iata: string;
  airline_name: string;
  flight_numbers: string[];
  flight_duration_minutes: number;
  distance_km: number;
  days_of_week: number[];
  aircraft_types: string[];
  source_record_id: string;
}

export interface AeroDataBoxConfig {
  apiKey: string;
  baseUrl?: string;
  apiHost?: string;
  fetchFn?: typeof fetch;
}

export function parseIsoDurationMinutes(durationStr: unknown): number {
  if (typeof durationStr === 'number' && Number.isFinite(durationStr) && durationStr > 0) {
    return Math.round(durationStr);
  }

  if (typeof durationStr !== 'string' || !durationStr.trim()) {
    return 120; // Default 2 hours fallback if missing
  }

  const str = durationStr.trim().toUpperCase();
  const regex = /^PT(?:(\d+)H)?(?:(\d+)M)?$/;
  const match = str.match(regex);

  if (match) {
    const hours = parseInt(match[1] || '0', 10);
    const minutes = parseInt(match[2] || '0', 10);
    const total = hours * 60 + minutes;
    return total > 0 ? total : 120;
  }

  const numericOnly = parseInt(str, 10);
  if (!Number.isNaN(numericOnly) && numericOnly > 0) {
    return numericOnly;
  }

  return 120;
}

export function parseDaysOfWeek(days: unknown): number[] {
  if (Array.isArray(days)) {
    const parsed = days
      .map((d) => (typeof d === 'number' ? d : parseInt(String(d), 10)))
      .filter((n) => Number.isInteger(n) && n >= 1 && n <= 7);
    if (parsed.length > 0) {
      return Array.from(new Set(parsed)).sort((a, b) => a - b);
    }
  }
  return [1, 2, 3, 4, 5, 6, 7];
}

export function parseAeroDataBoxDirectRoutes(
  originIata: string,
  payload: unknown,
): AeroDataBoxRoute[] {
  const normOrigin = originIata.trim().toUpperCase();
  if (!normOrigin || normOrigin.length !== 3) {
    return [];
  }

  if (!payload || typeof payload !== 'object') {
    return [];
  }

  const routesRaw = Array.isArray(payload)
    ? payload
    : Array.isArray((payload as Record<string, unknown>).routes)
    ? (payload as Record<string, unknown>).routes
    : Array.isArray((payload as Record<string, unknown>).destinations)
    ? (payload as Record<string, unknown>).destinations
    : [];

  const results: AeroDataBoxRoute[] = [];

  for (const item of routesRaw as Record<string, unknown>[]) {
    if (!item || typeof item !== 'object') continue;

    const destObj = item.destination as Record<string, unknown> | undefined;
    const destIata = (
      typeof item.destinationIata === 'string'
        ? item.destinationIata
        : typeof item.destination === 'string'
        ? item.destination
        : typeof destObj?.iata === 'string'
        ? destObj.iata
        : ''
    ).trim().toUpperCase();

    if (!destIata || destIata.length !== 3 || destIata === normOrigin) {
      continue;
    }

    const airlineObj = item.airline as Record<string, unknown> | undefined;
    const airlineIata = (
      typeof item.airlineIata === 'string'
        ? item.airlineIata
        : typeof item.airlineCode === 'string'
        ? item.airlineCode
        : typeof airlineObj?.iata === 'string'
        ? airlineObj.iata
        : ''
    ).trim().toUpperCase();

    if (!airlineIata || airlineIata.length < 2) {
      continue;
    }

    const airlineName = (
      typeof item.airlineName === 'string'
        ? item.airlineName
        : typeof airlineObj?.name === 'string'
        ? airlineObj.name
        : airlineIata
    ).trim();

    const flightNumbersRaw = Array.isArray(item.flightNumbers)
      ? item.flightNumbers
      : Array.isArray(item.flights)
      ? item.flights
      : typeof item.flightNumber === 'string'
      ? [item.flightNumber]
      : [];

    const flightNumbers = flightNumbersRaw
      .map((f) => String(f).trim().toUpperCase())
      .filter((f) => f.length >= 3);

    const durationMinutes = parseIsoDurationMinutes(
      item.duration ?? item.flightDurationMinutes ?? item.averageDuration,
    );

    const distanceKm = typeof item.distanceKm === 'number' && item.distanceKm > 0
      ? Math.round(item.distanceKm)
      : typeof item.distance === 'number' && item.distance > 0
      ? Math.round(item.distance)
      : 0;

    const daysOfWeek = parseDaysOfWeek(
      item.operatingDays ?? item.daysOfWeek ?? item.days,
    );

    const aircraftRaw = Array.isArray(item.aircraft)
      ? item.aircraft
      : Array.isArray(item.aircraftTypes)
      ? item.aircraftTypes
      : typeof item.aircraftType === 'string'
      ? [item.aircraftType]
      : [];

    const aircraftTypes = aircraftRaw
      .map((a) => String(a).trim().toUpperCase())
      .filter((a) => a.length >= 2);

    const sourceRecordId = `aerodatabox-${normOrigin}-${destIata}-${airlineIata}`;

    results.push({
      origin_iata: normOrigin,
      destination_iata: destIata,
      airline_iata: airlineIata,
      airline_name: airlineName || airlineIata,
      flight_numbers: flightNumbers,
      flight_duration_minutes: durationMinutes,
      distance_km: distanceKm,
      days_of_week: daysOfWeek,
      aircraft_types: aircraftTypes,
      source_record_id: sourceRecordId,
    });
  }

  return results;
}

export async function fetchDirectRoutesFromAeroDataBox(
  originIata: string,
  config: AeroDataBoxConfig,
): Promise<AeroDataBoxRoute[]> {
  const normOrigin = originIata.trim().toUpperCase();
  if (!normOrigin || normOrigin.length !== 3) {
    throw new Error('ERR_INVALID_IATA_CODE');
  }

  if (!config.apiKey || !config.apiKey.trim()) {
    throw new Error('ERR_MISSING_API_KEY');
  }

  const baseUrl = (config.baseUrl || 'https://aerodatabox.p.rapidapi.com').replace(/\/+$/, '');
  const url = `${baseUrl}/airports/iata/${normOrigin}/routes/direct`;
  const fetcher = config.fetchFn || fetch;

  const headers: Record<string, string> = {
    'Accept': 'application/json',
    'x-rapidapi-key': config.apiKey.trim(),
    'x-api-market-key': config.apiKey.trim(),
    'x-rapidapi-host': config.apiHost || 'aerodatabox.p.rapidapi.com',
  };

  const response = await fetcher(url, { method: 'GET', headers });

  if (response.status === 404) {
    return [];
  }

  if (!response.ok) {
    const errorText = await response.text().catch(() => '');
    throw new Error(`AeroDataBox API HTTP ${response.status}: ${errorText || response.statusText}`);
  }

  const json = await response.json();
  return parseAeroDataBoxDirectRoutes(normOrigin, json);
}
