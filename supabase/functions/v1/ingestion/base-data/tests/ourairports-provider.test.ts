import assert from 'node:assert/strict';
import { loadOurAirportsProvider, parseOurAirportsCsv } from '../providers/ourairports-provider.ts';

const AIRPORTS_CSV =
  `id,ident,type,name,latitude_deg,longitude_deg,elevation_ft,continent,iso_country,iso_region,municipality,scheduled_service,icao_code,iata_code,gps_code,local_code,home_link,wikipedia_link,keywords
2434,EGLL,large_airport,London Heathrow Airport,51.4706,-0.461941,83,EU,GB,GB-ENG,London,yes,EGLL,LHR,EGLL,,,https://example.test,
2435,EGKK,large_airport,"London, Gatwick Airport",51.1481,-0.190278,203,EU,GB,GB-ENG,London,yes,EGKK,LGW,EGKK,,,,
2436,EGLC,medium_airport,London City Airport,51.5053,0.055278,19,EU,GB,GB-ENG,London,no,EGLC,LCY,EGLC,,,,
2437,EGXX,small_airport,Commercial Small Airport,51,0,10,EU,GB,GB-ENG,London,yes,EGXX,XXX,EGXX,,,,
2438,EGYY,medium_airport,No IATA Airport,51,0,10,EU,GB,GB-ENG,London,yes,EGYY,,EGYY,,,,
2439,EGZZ,medium_airport,Denied Airport,51,0,10,EU,GB,GB-ENG,London,yes,EGZZ,ZZZ,EGZZ,,,,
`;

Deno.test('OurAirports parser keeps only scheduled large or medium airports with IATA', () => {
  const result = parseOurAirportsCsv(AIRPORTS_CSV, new Set(['ZZZ']));

  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.deepEqual(result.airports.map((airport) => airport.iata), ['LHR', 'LGW']);
  assert.equal(result.airports[1]?.name, 'London, Gatwick Airport');
  assert.equal(result.airports[0]?.sourceId, '2434');
  assert.deepEqual(result.metrics, {
    rawRecordCount: 6,
    eligibleRecordCount: 2,
    filteredRecordCount: 4,
    invalidRecordCount: 0,
  });
});

Deno.test('OurAirports parser rejects a changed or incomplete CSV header', () => {
  const result = parseOurAirportsCsv('id,name,iata_code\n1,Airport,AAA\n', new Set());

  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_UNSUPPORTED_SCHEMA_VERSION');
});

Deno.test('OurAirports parser rejects duplicate eligible IATA codes', () => {
  const duplicated = AIRPORTS_CSV.replace(
    '2439,EGZZ,medium_airport,Denied Airport',
    '2439,EGZZ,medium_airport,Duplicate Heathrow',
  ).replace(',EGZZ,ZZZ,EGZZ', ',EGZZ,LHR,EGZZ');
  const result = parseOurAirportsCsv(duplicated, new Set());

  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_DUPLICATE_SOURCE_KEY');
});

Deno.test('OurAirports provider enforces HTTPS, response size, and returns import metadata', async () => {
  const result = await loadOurAirportsProvider({
    airportsUrl: 'https://ourairports.example.test/airports.csv',
    denylist: new Set(['ZZZ']),
    maxDownloadBytes: 100_000,
    fetcher: () =>
      Promise.resolve(
        new Response(AIRPORTS_CSV, {
          headers: {
            etag: '"snapshot-1"',
            'last-modified': 'Tue, 11 Aug 2026 00:00:00 GMT',
          },
        }),
      ),
  });

  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.batch.airports.length, 2);
  assert.equal(result.batch.sourceTime, '2026-08-11T00:00:00.000Z');
  assert.equal(result.batch.importMetadata?.sourceEtag, '"snapshot-1"');
  assert.equal(result.batch.importMetadata?.rawRecordCount, 6);
  assert.match(result.batch.importMetadata?.sourceChecksum ?? '', /^[a-f0-9]{64}$/);
});

Deno.test('OurAirports provider refuses oversized downloads before parsing', async () => {
  const result = await loadOurAirportsProvider({
    airportsUrl: 'https://ourairports.example.test/airports.csv',
    denylist: new Set(),
    maxDownloadBytes: 10,
    fetcher: () =>
      Promise.resolve(new Response(AIRPORTS_CSV, { headers: { 'content-length': '999' } })),
  });

  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_PROVIDER_RECORD_LIMIT');
});
