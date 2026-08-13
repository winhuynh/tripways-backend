import assert from 'node:assert/strict';
import {
  createTravelpayoutsAdapter,
  normalizeTravelpayoutsResponse,
} from '../providers/travelpayouts-provider.ts';

Deno.test('Travelpayouts adapter maps cached results without inventing schedule facts', () => {
  const result = normalizeTravelpayoutsResponse({
    success: true,
    currency: 'usd',
    data: [{
      origin: 'SGN',
      destination: 'LON',
      origin_airport: 'SGN',
      destination_airport: 'LHR',
      airline: 'VN',
      price: 450,
      transfers: 0,
      duration: 780,
      departure_at: '2026-09-12',
      return_at: '',
      found_at: '2026-08-12T00:00:00Z',
      expires_at: '2026-08-14T00:00:00Z',
      link: '/search/SGN1209LON1',
    }],
  }, {
    marketCode: 'vn',
    locale: 'en-GB',
    observedAt: '2026-08-12T00:00:00Z',
  });
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.batch.observations[0]?.validUntil, '2026-08-14T00:00:00.000Z');
  assert.equal(result.batch.observations[0]?.direct, true);
});

Deno.test('Travelpayouts HTTP adapter scopes requests and keeps token in a header', async () => {
  const requests: Request[] = [];
  const adapter = createTravelpayoutsAdapter({
    token: 'secret-token',
    maxRecords: 100,
    now: () => new Date('2026-08-12T00:00:00Z'),
    fetcher: (input, init) => {
      requests.push(new Request(input, init));
      return Promise.resolve(
        new Response(JSON.stringify({ success: true, data: [], currency: 'usd' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }),
      );
    },
  });
  const result = await adapter.load({
    origin: 'SGN',
    destination: null,
    currencyCode: 'USD',
    marketCode: 'vn',
    locale: 'en-GB',
  });
  assert.equal(result.ok, true);
  assert.equal(requests.length, 1);
  const request = requests[0];
  assert.ok(request);
  assert.equal(new URL(request.url).searchParams.get('origin'), 'SGN');
  assert.equal(new URL(request.url).searchParams.get('page'), '1');
  assert.equal(new URL(request.url).searchParams.has('token'), false);
  assert.equal(request.headers.get('x-access-token'), 'secret-token');
});

Deno.test('Travelpayouts adapter paginates full pages and stops at the configured bound', async () => {
  const pages: string[] = [];
  const adapter = createTravelpayoutsAdapter({
    token: 'secret-token',
    maxRecords: 3,
    pageSize: 2,
    now: () => new Date('2026-08-12T00:00:00Z'),
    fetcher: (input) => {
      const page = new URL(input.toString()).searchParams.get('page') ?? '';
      pages.push(page);
      const start = page === '1' ? 0 : 2;
      const data = [start, start + 1].map((index) => ({
        origin: 'SGN',
        destination: `A${index}A`,
        origin_airport: 'SGN',
        destination_airport: `A${index}A`,
        price: 100 + index,
        transfers: 0,
        departure_at: `2026-09-${String(index + 1).padStart(2, '0')}`,
        found_at: '2026-08-12T00:00:00Z',
        expires_at: '2026-08-14T00:00:00Z',
      }));
      return Promise.resolve(Response.json({ success: true, currency: 'usd', data }));
    },
  });
  const result = await adapter.load({
    origin: 'SGN',
    destination: null,
    currencyCode: 'USD',
    marketCode: 'vn',
    locale: 'en-GB',
  });
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.deepEqual(pages, ['1', '2']);
  assert.equal(result.batch.observations.length, 3);
});

Deno.test('Travelpayouts adapter maps HTTP 429 to a stable rate-limit issue', async () => {
  const adapter = createTravelpayoutsAdapter({
    token: 'secret-token',
    maxRecords: 10,
    fetcher: () => Promise.resolve(new Response(null, { status: 429 })),
  });
  const result = await adapter.load({
    origin: 'SGN',
    destination: 'LON',
    currencyCode: 'USD',
    marketCode: 'vn',
    locale: 'en-GB',
  });
  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_PROVIDER_RATE_LIMITED');
});

Deno.test('Travelpayouts normalizer rejects malformed provider timestamps without throwing', () => {
  const result = normalizeTravelpayoutsResponse({
    success: true,
    currency: 'USD',
    data: [{ origin: 'SGN', destination: 'LHR', price: 450, found_at: 'invalid-date' }],
  }, { marketCode: 'vn', locale: 'en-GB', observedAt: '2026-08-12T00:00:00Z' });
  assert.equal(result.ok, false);
});
