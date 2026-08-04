import assert from 'node:assert/strict';
import { readVisitorCoordinates } from '../geolocation.ts';

Deno.test('reads IP-derived coordinates from the trusted Tripways headers', () => {
  const headers = new Headers({
    'x-tripways-geo-latitude': '40.6413',
    'x-tripways-geo-longitude': '-73.7781',
  });

  assert.deepEqual(readVisitorCoordinates(headers), {
    latitude: 40.6413,
    longitude: -73.7781,
  });
});

Deno.test('returns an empty input when geolocation headers are missing', () => {
  assert.deepEqual(readVisitorCoordinates(new Headers()), {});
});

Deno.test('returns an empty input when either coordinate is invalid', () => {
  const headers = new Headers({
    'x-tripways-geo-latitude': '91',
    'x-tripways-geo-longitude': '-73.7781',
  });

  assert.deepEqual(readVisitorCoordinates(headers), {});
});
