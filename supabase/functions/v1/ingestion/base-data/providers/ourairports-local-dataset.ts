import type {
  CanonicalBaseDataBatch,
  CanonicalCity,
  CanonicalCountry,
} from '../provider-contract.ts';
import { parseCsvRows, parseOurAirportsCsv } from './ourairports-provider.ts';

export type OurAirportsLocalDatasetManifest = {
  counts: {
    countries: number;
    cities: number;
    airports: number;
    airportsWithoutCity: number;
    unresolvedCountryCodes: number;
  };
  unresolvedCountryIso2: string[];
};

export type OurAirportsLocalDatasetResult =
  | {
    ok: true;
    dataset: Pick<CanonicalBaseDataBatch, 'countries' | 'cities' | 'airports'>;
    manifest: OurAirportsLocalDatasetManifest;
  }
  | { ok: false; unresolvedAirportCountryIso2: string[] };

export function buildOurAirportsLocalDataset(input: {
  airportsCsv: string;
  countriesCsv: string;
  countryCodesCsv: string;
  countryCodeOverrides?: Readonly<Record<string, string>>;
  denylist: ReadonlySet<string>;
}): OurAirportsLocalDatasetResult {
  const parsedAirports = parseOurAirportsCsv(input.airportsCsv, input.denylist);
  if (!parsedAirports.ok) return { ok: false, unresolvedAirportCountryIso2: [] };

  const countryCodeRows = rowsAsRecords(input.countryCodesCsv);
  const iso3ByIso2 = new Map<string, string>();
  const countryMetaByIso2 = new Map<
    string,
    {
      region: string | null;
      subregion: string | null;
      currencyCode: string | null;
      primaryLanguage: string | null;
    }
  >();
  for (const row of countryCodeRows) {
    const iso2 = row['ISO3166-1-Alpha-2']?.trim().toUpperCase() ?? '';
    const iso3 = row['ISO3166-1-Alpha-3']?.trim().toUpperCase() ?? '';
    const region = row['Region Name']?.trim() || null;
    const subregion = row['Sub-region Name']?.trim() || null;
    const currencyCode = row['ISO4217-currency_alphabetic_code']?.trim().toUpperCase() || null;
    const languages = row['Languages']?.split(',') ?? [];
    const primaryLanguage = languages[0]?.trim().slice(0, 5) || null;

    if (/^[A-Z]{2}$/.test(iso2) && /^[A-Z]{3}$/.test(iso3)) {
      iso3ByIso2.set(iso2, iso3);
      countryMetaByIso2.set(iso2, { region, subregion, currencyCode, primaryLanguage });
    }
  }
  for (const [iso2Value, iso3Value] of Object.entries(input.countryCodeOverrides ?? {})) {
    const iso2 = iso2Value.trim().toUpperCase();
    const iso3 = iso3Value.trim().toUpperCase();
    if (/^[A-Z]{2}$/.test(iso2) && /^[A-Z]{3}$/.test(iso3)) {
      iso3ByIso2.set(iso2, iso3);
    }
  }

  const countries: CanonicalCountry[] = [];
  const unresolvedCountryIso2: string[] = [];
  for (const row of rowsAsRecords(input.countriesCsv)) {
    const iso2 = row.code?.trim().toUpperCase() ?? '';
    const name = row.name?.trim() ?? '';
    const iso3 = iso3ByIso2.get(iso2);
    if (!iso3) {
      if (/^[A-Z]{2}$/.test(iso2)) unresolvedCountryIso2.push(iso2);
      continue;
    }
    const meta = countryMetaByIso2.get(iso2);
    if (name.length > 0) {
      countries.push({
        iso2,
        iso3,
        name,
        region: meta?.region ?? null,
        subregion: meta?.subregion ?? null,
      });
    }
  }
  countries.sort((left, right) => left.iso2.localeCompare(right.iso2));

  const supportedCountryIso2 = new Set(countries.map((country) => country.iso2));
  const unresolvedAirportCountryIso2 = [
    ...new Set(
      parsedAirports.airports
        .map((airport) => airport.countryIso2)
        .filter((iso2) => !supportedCountryIso2.has(iso2)),
    ),
  ].sort();
  if (unresolvedAirportCountryIso2.length > 0) {
    return { ok: false, unresolvedAirportCountryIso2 };
  }

  const locationByAirportId = new Map<string, { region: string; municipality: string }>();
  for (const row of rowsAsRecords(input.airportsCsv)) {
    const sourceId = row.id?.trim() ?? '';
    if (!sourceId) continue;
    locationByAirportId.set(sourceId, {
      region: row.iso_region?.trim().toLowerCase() ?? '',
      municipality: row.municipality?.trim() ?? '',
    });
  }

  const cityBySourceId = new Map<string, CanonicalCity>();
  let airportsWithoutCity = 0;
  const airports = parsedAirports.airports.map((airport) => {
    const location = locationByAirportId.get(airport.sourceId);
    if (!location?.municipality) {
      airportsWithoutCity += 1;
      return { ...airport, citySourceId: null };
    }
    const citySourceId = [
      'ourairports-city',
      airport.countryIso2.toLowerCase(),
      normalizeIdentityPart(location.region || 'unknown-region'),
      normalizeIdentityPart(location.municipality),
    ].join(':').slice(0, 160);

    const countryMeta = countryMetaByIso2.get(airport.countryIso2);
    const existingCity = cityBySourceId.get(citySourceId);
    if (!existingCity) {
      cityBySourceId.set(citySourceId, {
        sourceId: citySourceId,
        name: location.municipality,
        countryIso2: airport.countryIso2,
        currencyCode: countryMeta?.currencyCode ?? null,
        primaryLanguage: countryMeta?.primaryLanguage ?? null,
        latitude: airport.latitude,
        longitude: airport.longitude,
      });
    } else if (existingCity.latitude === null && airport.latitude !== null) {
      existingCity.latitude = airport.latitude;
      existingCity.longitude = airport.longitude;
    } else if (airport.type === 'large_airport' && airport.latitude !== null) {
      // Prioritize large airport coordinates for multi-airport city centers
      existingCity.latitude = airport.latitude;
      existingCity.longitude = airport.longitude;
    }

    return { ...airport, citySourceId };
  });

  const cities = [...cityBySourceId.values()].sort((left, right) =>
    left.sourceId.localeCompare(right.sourceId)
  );
  const unresolved = [...new Set(unresolvedCountryIso2)].sort();
  return {
    ok: true,
    dataset: { countries, cities, airports },
    manifest: {
      counts: {
        countries: countries.length,
        cities: cities.length,
        airports: airports.length,
        airportsWithoutCity,
        unresolvedCountryCodes: unresolved.length,
      },
      unresolvedCountryIso2: unresolved,
    },
  };
}

function rowsAsRecords(csv: string): Array<Record<string, string>> {
  const rows = parseCsvRows(csv);
  const headers = rows[0]?.map((value) => value.replace(/^\uFEFF/, '').trim()) ?? [];
  return rows.slice(1)
    .filter((row) => !(row.length === 1 && row[0]?.trim() === ''))
    .map((row) => Object.fromEntries(headers.map((header, index) => [header, row[index] ?? ''])));
}

function normalizeIdentityPart(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '') || 'unknown';
}
