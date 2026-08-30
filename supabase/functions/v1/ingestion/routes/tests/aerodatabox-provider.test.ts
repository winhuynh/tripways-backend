import assert from 'node:assert/strict';
import {
  fetchDirectRoutesFromAeroDataBox,
  parseAeroDataBoxDirectRoutes,
  parseDaysOfWeek,
  parseIsoDurationMinutes,
} from '../providers/aerodatabox-provider.ts';

Deno.test('parseIsoDurationMinutes parses ISO 8601 durations and numeric strings', () => {
  assert.equal(parseIsoDurationMinutes('PT2H05M'), 125);
  assert.equal(parseIsoDurationMinutes('PT1H'), 60);
  assert.equal(parseIsoDurationMinutes('PT45M'), 45);
  assert.equal(parseIsoDurationMinutes('PT12H30M'), 750);
  assert.equal(parseIsoDurationMinutes(180), 180);
  assert.equal(parseIsoDurationMinutes('90'), 90);
  assert.equal(parseIsoDurationMinutes(''), 120);
  assert.equal(parseIsoDurationMinutes(null), 120);
});

Deno.test('parseDaysOfWeek normalizes numbers and array items to sorted unique week days', () => {
  assert.deepEqual(parseDaysOfWeek([1, 2, 3, 4, 5, 6, 7]), [1, 2, 3, 4, 5, 6, 7]);
  assert.deepEqual(parseDaysOfWeek([5, 1, 3, 1]), [1, 3, 5]);
  assert.deepEqual(parseDaysOfWeek(['1', '2', '7']), [1, 2, 7]);
  assert.deepEqual(parseDaysOfWeek([]), [1, 2, 3, 4, 5, 6, 7]);
  assert.deepEqual(parseDaysOfWeek(null), [1, 2, 3, 4, 5, 6, 7]);
});

Deno.test('parseAeroDataBoxDirectRoutes parses AeroDataBox response payload', () => {
  const samplePayload = {
    routes: [
      {
        destination: {
          iata: 'SIN',
          icao: 'WSSS',
          name: 'Singapore Changi Airport',
        },
        airline: {
          name: 'Singapore Airlines',
          iata: 'SQ',
        },
        flightNumbers: ['SQ173', 'SQ177'],
        operatingDays: [1, 2, 3, 4, 5, 6, 7],
        duration: 'PT2H05M',
        distanceKm: 1085,
        aircraft: ['B787', 'A350'],
      },
      {
        destinationIata: 'LHR',
        airlineIata: 'VN',
        airlineName: 'Vietnam Airlines',
        flightNumber: 'VN51',
        daysOfWeek: [2, 4, 6],
        flightDurationMinutes: 780,
        distance: 10200,
        aircraftType: 'B787',
      },
    ],
  };

  const parsed = parseAeroDataBoxDirectRoutes('SGN', samplePayload);

  assert.equal(parsed.length, 2);

  const [r1, r2] = parsed;
  assert.ok(r1 !== undefined);
  assert.ok(r2 !== undefined);

  assert.equal(r1.origin_iata, 'SGN');
  assert.equal(r1.destination_iata, 'SIN');
  assert.equal(r1.airline_iata, 'SQ');
  assert.equal(r1.airline_name, 'Singapore Airlines');
  assert.deepEqual(r1.flight_numbers, ['SQ173', 'SQ177']);
  assert.equal(r1.flight_duration_minutes, 125);
  assert.equal(r1.distance_km, 1085);
  assert.deepEqual(r1.days_of_week, [1, 2, 3, 4, 5, 6, 7]);
  assert.deepEqual(r1.aircraft_types, ['B787', 'A350']);
  assert.equal(r1.source_record_id, 'aerodatabox-SGN-SIN-SQ');

  assert.equal(r2.origin_iata, 'SGN');
  assert.equal(r2.destination_iata, 'LHR');
  assert.equal(r2.airline_iata, 'VN');
  assert.deepEqual(r2.flight_numbers, ['VN51']);
  assert.equal(r2.flight_duration_minutes, 780);
  assert.equal(r2.distance_km, 10200);
  assert.deepEqual(r2.days_of_week, [2, 4, 6]);
  assert.equal(r2.source_record_id, 'aerodatabox-SGN-LHR-VN');
});

Deno.test('fetchDirectRoutesFromAeroDataBox handles 404 cleanly and returns empty array', async () => {
  const mockFetch: typeof fetch = (_input, _init) => {
    return Promise.resolve(new Response('Not Found', { status: 404 }));
  };

  const routes = await fetchDirectRoutesFromAeroDataBox('SGN', {
    apiKey: 'test-key-12345678',
    fetchFn: mockFetch,
  });

  assert.deepEqual(routes, []);
});

Deno.test('fetchDirectRoutesFromAeroDataBox propagates API errors', async () => {
  const mockFetch: typeof fetch = (_input, _init) => {
    return Promise.resolve(new Response('Rate limit exceeded', { status: 429 }));
  };

  await assert.rejects(
    () =>
      fetchDirectRoutesFromAeroDataBox('SGN', {
        apiKey: 'test-key-12345678',
        fetchFn: mockFetch,
      }),
    /AeroDataBox API HTTP 429/,
  );
});
