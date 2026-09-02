import assert from 'node:assert/strict';
import {
  fetchRoutePricesFromTravelpayouts,
  parseTravelpayoutsFareObservations,
  type TravelpayoutsConfig,
} from '../providers/travelpayouts-provider.ts';

const validTravelpayoutsPayload = {
  success: true,
  data: [
    {
      origin: 'SGN',
      destination: 'HAN',
      origin_airport: 'SGN',
      destination_airport: 'HAN',
      price: 85,
      airline: 'VN',
      flight_number: '210',
      departure_at: '2026-09-15T06:00:00+07:00',
      return_at: null,
      transfers: 0,
      duration: 125,
      duration_to: 125,
      duration_back: 0,
      link: '/search/SGN1509HAN1',
      found_at: '2026-09-01T12:00:00.000Z',
    },
    {
      origin: 'SGN',
      destination: 'LHR',
      origin_airport: 'SGN',
      destination_airport: 'LHR',
      price: 650.5,
      airline: 'QR',
      flight_number: '971',
      departure_at: '2026-09-20T19:30:00Z',
      return_at: '2026-10-05T10:00:00Z',
      transfers: 1,
      duration: 1050,
      duration_to: 1050,
      duration_back: 1100,
      link: '/search/SGN2009LHR05101',
      found_at: '2026-09-01T10:00:00.000Z',
    },
  ],
  currency: 'USD',
};

Deno.test('parseTravelpayoutsFareObservations parses direct and connecting flights with dates and prices', () => {
  const observations = parseTravelpayoutsFareObservations('SGN', validTravelpayoutsPayload);

  assert.equal(observations.length, 2);

  const [directObs, connObs] = observations;
  assert.ok(directObs !== undefined);
  assert.ok(connObs !== undefined);

  // Direct flight
  assert.equal(directObs.originIata, 'SGN');
  assert.equal(directObs.destinationIata, 'HAN');
  assert.equal(directObs.providerAirlineIata, 'VN');
  assert.equal(directObs.observedAmount, 85);
  assert.equal(directObs.currencyCode, 'USD');
  assert.equal(directObs.departureDate, '2026-09-15');
  assert.equal(directObs.returnDate, null);
  assert.equal(directObs.direct, true);
  assert.equal(directObs.transferCount, 0);
  assert.equal(directObs.durationMinutes, 125);
  assert.equal(directObs.foundAt, '2026-09-01T12:00:00.000Z');
  assert.equal(directObs.validUntil, '2026-09-08T12:00:00.000Z');
  assert.equal(directObs.affiliatePath, '/search/SGN1509HAN1');

  // Connecting return flight
  assert.equal(connObs.originIata, 'SGN');
  assert.equal(connObs.destinationIata, 'LHR');
  assert.equal(connObs.providerAirlineIata, 'QR');
  assert.equal(connObs.observedAmount, 650.5);
  assert.equal(connObs.currencyCode, 'USD');
  assert.equal(connObs.departureDate, '2026-09-20');
  assert.equal(connObs.returnDate, '2026-10-05');
  assert.equal(connObs.direct, false);
  assert.equal(connObs.transferCount, 1);
  assert.equal(connObs.durationMinutes, 1050);
  assert.equal(connObs.foundAt, '2026-09-01T10:00:00.000Z');
  assert.equal(connObs.validUntil, '2026-09-08T10:00:00.000Z');
  assert.equal(connObs.affiliatePath, '/search/SGN2009LHR05101');
});

Deno.test('parseTravelpayoutsFareObservations handles invalid and empty payloads safely', () => {
  assert.deepEqual(parseTravelpayoutsFareObservations('SGN', null), []);
  assert.deepEqual(parseTravelpayoutsFareObservations('SGN', undefined), []);
  assert.deepEqual(parseTravelpayoutsFareObservations('SGN', {}), []);
  assert.deepEqual(parseTravelpayoutsFareObservations('SGN', { data: [] }), []);
  assert.deepEqual(parseTravelpayoutsFareObservations('SGN', { data: null }), []);
  assert.deepEqual(parseTravelpayoutsFareObservations('INVALID', validTravelpayoutsPayload), []);
  assert.deepEqual(parseTravelpayoutsFareObservations('', validTravelpayoutsPayload), []);

  // Payload with same origin & destination or invalid destination code
  const malformedPayload = {
    data: [
      { origin: 'SGN', destination: 'SGN', price: 100 }, // same origin/destination
      { origin: 'SGN', destination: 'INVALID_CODE', price: 100 }, // invalid code length
      null,
      'not an object',
    ],
  };
  assert.deepEqual(parseTravelpayoutsFareObservations('SGN', malformedPayload), []);
});

Deno.test('parseTravelpayoutsFareObservations enforces 7-day TTL capping on validUntil', () => {
  const foundAtStr = '2026-09-01T00:00:00.000Z';
  const fourteenDaysLater = '2026-09-15T00:00:00.000Z';
  const threeDaysLater = '2026-09-04T00:00:00.000Z';
  const sevenDaysLater = '2026-09-08T00:00:00.000Z';

  const payload = {
    data: [
      {
        destination: 'HAN',
        price: 90,
        found_at: foundAtStr,
        valid_until: fourteenDaysLater, // Excess validity (> 7 days)
      },
      {
        destination: 'DAD',
        price: 70,
        found_at: foundAtStr,
        valid_until: threeDaysLater, // Shorter validity (3 days)
      },
      {
        destination: 'BKK',
        price: 110,
        found_at: foundAtStr,
        // No valid_until provided
      },
    ],
  };

  const observations = parseTravelpayoutsFareObservations('SGN', payload);
  assert.equal(observations.length, 3);

  const [obs1, obs2, obs3] = observations;
  assert.ok(obs1 && obs2 && obs3);

  // Obs 1: Capped to 7 days
  assert.equal(obs1.validUntil, sevenDaysLater);
  const ttl1 = Date.parse(obs1.validUntil) - Date.parse(obs1.foundAt);
  assert.ok(ttl1 <= 7 * 24 * 60 * 60 * 1000);

  // Obs 2: Preserved within 7 days
  assert.equal(obs2.validUntil, threeDaysLater);

  // Obs 3: Defaults to 7 days
  assert.equal(obs3.validUntil, sevenDaysLater);
});

Deno.test('parseTravelpayoutsFareObservations sanitizes affiliate URLs', () => {
  const payload = {
    data: [
      {
        destination: 'HAN',
        price: 80,
        link: '/search/SGN1509HAN1',
      },
      {
        destination: 'DAD',
        price: 60,
        link: 'https://www.aviasales.com/search/SGN1509DAD1?marker=12345',
      },
      {
        destination: 'BKK',
        price: 120,
        link: '//evil.com/hack', // Protocol-relative link must be rejected
      },
    ],
  };

  const observations = parseTravelpayoutsFareObservations('SGN', payload);
  assert.equal(observations.length, 3);

  assert.equal(observations[0]?.affiliatePath, '/search/SGN1509HAN1');
  assert.equal(
    observations[1]?.affiliatePath,
    '/search/SGN1509DAD1?marker=12345',
  );
  assert.equal(observations[2]?.affiliatePath, null);
});

Deno.test('fetchRoutePricesFromTravelpayouts executes GET with x-access-token header', async () => {
  let capturedUrl = '';
  let capturedHeaders: Record<string, string> = {};

  const mockFetch: typeof fetch = (input, init) => {
    capturedUrl = String(input);
    const headersRecord = (init as { headers?: Record<string, string> } | undefined)?.headers;
    if (headersRecord) {
      capturedHeaders = { ...headersRecord };
    }
    return Promise.resolve(
      new Response(JSON.stringify(validTravelpayoutsPayload), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  };

  const config: TravelpayoutsConfig = {
    apiToken: 'secret-test-token-xyz',
    fetchFn: mockFetch,
  };

  const observations = await fetchRoutePricesFromTravelpayouts(config, {
    originIata: 'sgn',
    destIata: 'han',
    currency: 'USD',
    market: 'vn',
    locale: 'en-GB',
  });

  assert.equal(observations.length, 2);
  const urlObj = new URL(capturedUrl);
  assert.equal(urlObj.searchParams.get('origin'), 'SGN');
  assert.equal(urlObj.searchParams.get('destination'), 'HAN');
  assert.equal(urlObj.searchParams.get('currency'), 'usd');
  assert.equal(urlObj.searchParams.get('market'), 'vn');
  assert.equal(urlObj.searchParams.get('locale'), 'en-gb');

  // Verify header includes token
  assert.equal(
    capturedHeaders['x-access-token'],
    'secret-test-token-xyz',
  );
});

Deno.test('fetchRoutePricesFromTravelpayouts handles 404 cleanly by returning empty array', async () => {
  const mockFetch: typeof fetch = () => {
    return Promise.resolve(new Response('Not Found', { status: 404 }));
  };

  const observations = await fetchRoutePricesFromTravelpayouts(
    { apiToken: 'token123', fetchFn: mockFetch },
    { originIata: 'SGN' },
  );

  assert.deepEqual(observations, []);
});

Deno.test('fetchRoutePricesFromTravelpayouts propagates network errors without leaking secrets', async () => {
  const secretToken = 'super-confidential-token-999';

  // 429 Rate limited
  const mock429: typeof fetch = () => {
    return Promise.resolve(new Response('Rate Limit Exceeded', { status: 429 }));
  };
  await assert.rejects(
    () =>
      fetchRoutePricesFromTravelpayouts(
        { apiToken: secretToken, fetchFn: mock429 },
        { originIata: 'SGN' },
      ),
    /ERR_PROVIDER_RATE_LIMITED/,
  );

  // 401 Unauthorized
  const mock401: typeof fetch = () => {
    return Promise.resolve(new Response('Unauthorized', { status: 401 }));
  };
  await assert.rejects(
    () =>
      fetchRoutePricesFromTravelpayouts(
        { apiToken: secretToken, fetchFn: mock401 },
        { originIata: 'SGN' },
      ),
    /ERR_PROVIDER_UNAUTHORIZED/,
  );

  // Network connection error
  const mockNetworkFail: typeof fetch = () => {
    return Promise.reject(new Error(`Failed to fetch from upstream: ${secretToken}`));
  };
  const err = await fetchRoutePricesFromTravelpayouts(
    { apiToken: secretToken, fetchFn: mockNetworkFail },
    { originIata: 'SGN' },
  ).catch((e) => e);

  assert.ok(err instanceof Error);
  assert.equal(err.message.includes(secretToken), false);
  assert.ok(err.message.includes('[redacted]'));
});

Deno.test('fetchRoutePricesFromTravelpayouts validates required origin IATA and token', async () => {
  await assert.rejects(
    () =>
      fetchRoutePricesFromTravelpayouts(
        { apiToken: 'token123' },
        { originIata: 'INVALID_IATA' },
      ),
    /ERR_INVALID_IATA_CODE/,
  );

  await assert.rejects(
    () =>
      fetchRoutePricesFromTravelpayouts(
        { apiToken: '' },
        { originIata: 'SGN' },
      ),
    /ERR_MISSING_API_TOKEN/,
  );
});
