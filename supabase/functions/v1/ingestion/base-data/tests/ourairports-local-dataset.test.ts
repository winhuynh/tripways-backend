import assert from 'node:assert/strict';
import { buildOurAirportsLocalDataset } from '../providers/ourairports-local-dataset.ts';

const AIRPORTS_CSV =
  `id,ident,type,name,latitude_deg,longitude_deg,elevation_ft,continent,iso_country,iso_region,municipality,scheduled_service,icao_code,iata_code,gps_code,local_code,home_link,wikipedia_link,keywords
1,EGLL,large_airport,London Heathrow Airport,51.4706,-0.461941,83,EU,GB,GB-ENG,London,yes,EGLL,LHR,EGLL,,,,
2,LFMN,large_airport,Nice Côte d'Azur Airport,43.6584,7.21587,12,EU,FR,FR-PAC,Nice,yes,LFMN,NCE,LFMN,,,,
3,LFXX,medium_airport,No Municipality Airport,44,7,10,EU,FR,FR-PAC,,yes,LFXX,NMA,LFXX,,,,
4,EGXX,small_airport,Filtered Airport,51,0,10,EU,GB,GB-ENG,London,yes,EGXX,XXX,EGXX,,,,
`;

const COUNTRIES_CSV = `id,code,name,continent,wikipedia_link,keywords
1,GB,United Kingdom,EU,,
2,FR,France,EU,,
3,ZZ,Unsupported Country,EU,,
`;

const COUNTRY_CODES_CSV = `ISO3166-1-Alpha-3,ISO3166-1-Alpha-2,Region Name,Sub-region Name
GBR,GB,Europe,Northern Europe
FRA,FR,Europe,Western Europe
`;

Deno.test('local dataset joins ISO3, derives cities, and links eligible airports', () => {
  const result = buildOurAirportsLocalDataset({
    airportsCsv: AIRPORTS_CSV,
    countriesCsv: COUNTRIES_CSV,
    countryCodesCsv: COUNTRY_CODES_CSV,
    denylist: new Set(),
  });

  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.deepEqual(result.dataset.countries, [
    { iso2: 'FR', iso3: 'FRA', name: 'France', region: 'Europe', subregion: 'Western Europe' },
    {
      iso2: 'GB',
      iso3: 'GBR',
      name: 'United Kingdom',
      region: 'Europe',
      subregion: 'Northern Europe',
    },
  ]);
  assert.deepEqual(result.dataset.cities, [
    {
      sourceId: 'ourairports-city:fr:fr-pac:nice',
      name: 'Nice',
      countryIso2: 'FR',
      currencyCode: null,
      primaryLanguage: null,
      latitude: 43.6584,
      longitude: 7.21587,
    },
    {
      sourceId: 'ourairports-city:gb:gb-eng:london',
      name: 'London',
      countryIso2: 'GB',
      currencyCode: null,
      primaryLanguage: null,
      latitude: 51.4706,
      longitude: -0.461941,
    },
  ]);
  assert.equal(result.dataset.airports.length, 3);
  assert.equal(result.dataset.airports[0]?.citySourceId, 'ourairports-city:gb:gb-eng:london');
  assert.equal(result.dataset.airports[2]?.citySourceId, null);
  assert.deepEqual(result.manifest.counts, {
    countries: 2,
    cities: 2,
    airports: 3,
    airportsWithoutCity: 1,
    unresolvedCountryCodes: 1,
  });
  assert.deepEqual(result.manifest.unresolvedCountryIso2, ['ZZ']);
});

Deno.test('local dataset rejects an eligible airport whose country has no ISO3 mapping', () => {
  const result = buildOurAirportsLocalDataset({
    airportsCsv: AIRPORTS_CSV.replace(',FR,FR-PAC,Nice,', ',ZZ,ZZ-01,Nice,'),
    countriesCsv: COUNTRIES_CSV,
    countryCodesCsv: COUNTRY_CODES_CSV,
    denylist: new Set(),
  });

  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.deepEqual(result.unresolvedAirportCountryIso2, ['ZZ']);
});

Deno.test('local dataset applies explicit non-ISO country overrides for local testing', () => {
  const result = buildOurAirportsLocalDataset({
    airportsCsv: AIRPORTS_CSV.replace(',FR,FR-PAC,Nice,', ',XK,XK-01,Pristina,'),
    countriesCsv: `${COUNTRIES_CSV}4,XK,Kosovo,EU,,\n`,
    countryCodesCsv: COUNTRY_CODES_CSV,
    countryCodeOverrides: { XK: 'XKX' },
    denylist: new Set(),
  });

  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.deepEqual(
    result.dataset.countries.find((country) => country.iso2 === 'XK'),
    { iso2: 'XK', iso3: 'XKX', name: 'Kosovo', region: null, subregion: null },
  );
});
