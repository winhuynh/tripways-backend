import assert from 'node:assert/strict';
import { parseCanonicalBaseDataBatch } from '../provider-contract.ts';

const validPayload = {
  schemaVersion: 'base-data.v1',
  sourceTime: null,
  countries: [{ iso2: 'SG', iso3: 'SGP', name: 'Singapore' }],
  cities: [{
    sourceId: 'city-sin',
    name: 'Singapore',
    countryIso2: 'SG',
    latitude: 1.3521,
    longitude: 103.8198,
  }],
  airports: [{
    sourceId: 'airport-sin',
    name: 'Singapore Changi Airport',
    iata: 'SIN',
    icao: 'WSSS',
    citySourceId: 'city-sin',
    countryIso2: 'SG',
    latitude: 1.3644,
    longitude: 103.9915,
    type: 'large_airport',
  }],
};

Deno.test('canonical parser accepts a complete base-data.v1 batch', () => {
  const result = parseCanonicalBaseDataBatch(validPayload);

  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.batch.schemaVersion, 'base-data.v1');
  assert.equal(result.batch.airports[0]?.iata, 'SIN');
});

Deno.test('canonical parser preserves unknown optional values as null', () => {
  const payload = structuredClone(validPayload);
  payload.cities[0]!.latitude = null as unknown as number;
  payload.cities[0]!.longitude = null as unknown as number;
  payload.airports[0]!.iata = null as unknown as string;
  payload.airports[0]!.icao = null as unknown as string;
  payload.airports[0]!.citySourceId = null as unknown as string;
  payload.airports[0]!.latitude = null as unknown as number;
  payload.airports[0]!.longitude = null as unknown as number;

  const result = parseCanonicalBaseDataBatch(payload);

  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.batch.cities[0]?.latitude, null);
  assert.equal(result.batch.airports[0]?.citySourceId, null);
});

Deno.test('canonical parser rejects duplicate identities and invalid records', () => {
  const payload = structuredClone(validPayload);
  payload.cities.push(structuredClone(payload.cities[0]!));
  payload.airports[0]!.latitude = 91;

  const result = parseCanonicalBaseDataBatch(payload);

  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.deepEqual(
    result.issues.map((issue) => issue.code),
    ['ERR_DUPLICATE_SOURCE_KEY', 'ERR_INVALID_COORDINATES'],
  );
});

Deno.test('canonical parser rejects missing required fields and unresolved references', () => {
  const payload = structuredClone(validPayload) as Record<string, unknown>;
  const countries = payload.countries as Array<Record<string, unknown>>;
  const airports = payload.airports as Array<Record<string, unknown>>;
  delete countries[0]!.name;
  airports[0]!.citySourceId = 'missing-city';

  const result = parseCanonicalBaseDataBatch(payload);

  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.deepEqual(
    result.issues.map((issue) => issue.code),
    [
      'ERR_MISSING_REQUIRED_FIELD',
      'ERR_UNRESOLVED_REFERENCE',
      'ERR_UNRESOLVED_REFERENCE',
    ],
  );
});

Deno.test('canonical parser rejects unknown schema versions', () => {
  const result = parseCanonicalBaseDataBatch({ ...validPayload, schemaVersion: 'base-data.v2' });

  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_UNSUPPORTED_SCHEMA_VERSION');
});
