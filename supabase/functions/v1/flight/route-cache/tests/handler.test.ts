import assert from 'node:assert/strict';
import type { SupabaseClient } from '@supabase/supabase-js';
import { createRouteCacheHandler } from '../handler.ts';
import type {
  NormalizedPriceObservation,
  TravelpayoutsConfig,
  TravelpayoutsFetchParams,
} from '../../../ingestion/price-estimates/providers/travelpayouts-provider.ts';

function createMockSupabaseClient(
  rpcHandler: (
    name: string,
    params: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: unknown }>,
) {
  const client = {
    schema: (_schemaName: string) => ({
      rpc: (name: string, params: Record<string, unknown>) => rpcHandler(name, params),
    }),
    rpc: (name: string, params: Record<string, unknown>) => rpcHandler(name, params),
  };
  return client as unknown as SupabaseClient;
}

Deno.test('route-cache handler: cache hit (fresh) returns observations immediately without calling provider', async () => {
  let providerCalled = false;
  const mockObservations = [
    {
      observation_ref: 'obs_1234567890abcdef1234567890abcdef',
      observed_amount: 320.5,
      currency_code: 'USD',
      departure_date: '2026-09-10',
      direct: true,
      transfer_count: 0,
      duration_minutes: 720,
      observed_at: '2026-09-01T00:00:00Z',
      valid_until: '2026-09-08T00:00:00Z',
    },
  ];

  const mockClient = createMockSupabaseClient((name, params) => {
    assert.equal(name, 'rpc_acquire_price_refresh_lease');
    assert.equal(params.p_origin_iata, 'BKK');
    assert.equal(params.p_destination_iata, 'LON');
    assert.equal(params.p_currency_code, 'USD');
    assert.equal(params.p_market_code, 'us');
    return Promise.resolve({
      data: {
        status: 'fresh',
        origin: 'BKK',
        destination: 'LON',
        count: 1,
        observations: mockObservations,
      },
      error: null,
    });
  });

  const fetchProviderPrices = (
    _config: TravelpayoutsConfig,
    _params: TravelpayoutsFetchParams,
  ) => {
    providerCalled = true;
    return Promise.resolve([]);
  };

  const handler = createRouteCacheHandler({
    getSupabaseClient: () => mockClient,
    fetchProviderPrices,
  });

  const request = new Request('http://local/route-cache', {
    method: 'POST',
    body: JSON.stringify({ originIata: 'BKK', destIata: 'LON' }),
  });

  const response = await handler(request);
  assert.equal(response.status, 200);
  const json = await response.json();
  assert.equal(json.error, null);
  assert.equal(json.data.status, 'fresh');
  assert.equal(json.data.origin, 'BKK');
  assert.equal(json.data.destination, 'LON');
  assert.equal(json.data.count, 1);
  assert.deepEqual(json.data.observations, mockObservations);
  assert.equal(providerCalled, false);
});

Deno.test('route-cache handler: cache miss (lease_acquired) calls provider, publishes, and returns result', async () => {
  const providerCalls: TravelpayoutsFetchParams[] = [];
  const publishCalls: Record<string, unknown>[] = [];

  const mockProviderObservations: NormalizedPriceObservation[] = [
    {
      originIata: 'BKK',
      destinationIata: 'LON',
      providerAirlineIata: 'TG',
      observedAmount: 450,
      currencyCode: 'USD',
      departureDate: '2026-09-15',
      returnDate: null,
      direct: true,
      transferCount: 0,
      durationMinutes: 680,
      foundAt: '2026-09-01T12:00:00Z',
      validUntil: '2026-09-08T12:00:00Z',
      affiliatePath: '/search/BKKLON',
    },
  ];

  const mockClient = createMockSupabaseClient((name, params) => {
    if (name === 'rpc_acquire_price_refresh_lease') {
      return Promise.resolve({
        data: {
          status: 'lease_acquired',
          origin: 'BKK',
          destination: 'LON',
          lease_id: 'lease-xyz',
        },
        error: null,
      });
    }
    if (name === 'rpc_publish_price_observations') {
      publishCalls.push(params);
      return Promise.resolve({
        data: {
          published_count: 1,
          status: 'fresh',
        },
        error: null,
      });
    }
    return Promise.reject(new Error(`Unexpected RPC: ${name}`));
  });

  const fetchProviderPrices = (
    _config: TravelpayoutsConfig,
    params: TravelpayoutsFetchParams,
  ) => {
    providerCalls.push(params);
    return Promise.resolve(mockProviderObservations);
  };

  const handler = createRouteCacheHandler({
    getSupabaseClient: () => mockClient,
    fetchProviderPrices,
    travelpayoutsConfig: { apiToken: 'test-token' },
  });

  const request = new Request('http://local/route-cache', {
    method: 'POST',
    body: JSON.stringify({
      origin: 'bkk',
      destination: 'lon',
      currency: 'USD',
      market: 'us',
      locale: 'en-GB',
    }),
  });

  const response = await handler(request);
  assert.equal(response.status, 200);
  const json = await response.json();
  assert.equal(json.error, null);
  assert.equal(json.data.status, 'fresh');
  assert.equal(json.data.published_count, 1);
  assert.equal(json.data.origin, 'BKK');
  assert.equal(json.data.destination, 'LON');
  assert.equal(json.data.observations.length, 1);

  assert.equal(providerCalls.length, 1);
  assert.equal(providerCalls[0]?.originIata, 'BKK');
  assert.equal(providerCalls[0]?.destIata, 'LON');
  assert.equal(providerCalls[0]?.currency, 'USD');
  assert.equal(providerCalls[0]?.market, 'us');
  assert.equal(providerCalls[0]?.locale, 'en-GB');

  assert.equal(publishCalls.length, 1);
  assert.equal(publishCalls[0]?.p_origin_iata, 'BKK');
  assert.equal(publishCalls[0]?.p_destination_iata, 'LON');
  assert.deepEqual(publishCalls[0]?.p_observations, mockProviderObservations);
});

Deno.test('route-cache handler: cooldown returns status empty without calling provider', async () => {
  let providerCalled = false;

  const mockClient = createMockSupabaseClient((name, _params) => {
    assert.equal(name, 'rpc_acquire_price_refresh_lease');
    return Promise.resolve({
      data: {
        status: 'cooldown',
        origin: 'BKK',
        destination: 'LON',
        next_allowed_refresh_at: '2026-09-02T12:00:00Z',
      },
      error: null,
    });
  });

  const fetchProviderPrices = () => {
    providerCalled = true;
    return Promise.resolve([]);
  };

  const handler = createRouteCacheHandler({
    getSupabaseClient: () => mockClient,
    fetchProviderPrices,
  });

  const request = new Request('http://local/route-cache', {
    method: 'POST',
    body: JSON.stringify({ originIata: 'BKK', destIata: 'LON' }),
  });

  const response = await handler(request);
  assert.equal(response.status, 200);
  const json = await response.json();
  assert.equal(json.error, null);
  assert.equal(json.data.status, 'empty');
  assert.equal(json.data.origin, 'BKK');
  assert.equal(json.data.destination, 'LON');
  assert.equal(json.data.next_allowed_refresh_at, '2026-09-02T12:00:00Z');
  assert.equal(providerCalled, false);
});

Deno.test('route-cache handler: refreshing returns status loading without calling provider', async () => {
  let providerCalled = false;

  const mockClient = createMockSupabaseClient((name, _params) => {
    assert.equal(name, 'rpc_acquire_price_refresh_lease');
    return Promise.resolve({
      data: {
        status: 'refreshing',
        origin: 'BKK',
        destination: null,
      },
      error: null,
    });
  });

  const fetchProviderPrices = () => {
    providerCalled = true;
    return Promise.resolve([]);
  };

  const handler = createRouteCacheHandler({
    getSupabaseClient: () => mockClient,
    fetchProviderPrices,
  });

  const request = new Request('http://local/route-cache', {
    method: 'POST',
    body: JSON.stringify({ originIata: 'BKK' }),
  });

  const response = await handler(request);
  assert.equal(response.status, 200);
  const json = await response.json();
  assert.equal(json.error, null);
  assert.equal(json.data.status, 'loading');
  assert.equal(json.data.origin, 'BKK');
  assert.equal(json.data.destination, null);
  assert.equal(providerCalled, false);
});

Deno.test('route-cache handler: validates inputs and rejects invalid requests', async () => {
  const mockClient = createMockSupabaseClient(() => Promise.resolve({ data: null, error: null }));
  const handler = createRouteCacheHandler({
    getSupabaseClient: () => mockClient,
  });

  // Invalid origin IATA (less than 3 chars)
  {
    const response = await handler(
      new Request('http://local/route-cache', {
        method: 'POST',
        body: JSON.stringify({ originIata: 'BK' }),
      }),
    );
    assert.equal(response.status, 400);
    const json = await response.json();
    assert.equal(json.error.code, 'ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }

  // Same origin and destination
  {
    const response = await handler(
      new Request('http://local/route-cache', {
        method: 'POST',
        body: JSON.stringify({ originIata: 'BKK', destIata: 'BKK' }),
      }),
    );
    assert.equal(response.status, 400);
    const json = await response.json();
    assert.equal(json.error.code, 'ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }

  // Unknown/forbidden fields
  {
    const response = await handler(
      new Request('http://local/route-cache', {
        method: 'POST',
        body: JSON.stringify({ originIata: 'BKK', injection: 'drop database' }),
      }),
    );
    assert.equal(response.status, 400);
    const json = await response.json();
    assert.equal(json.error.code, 'ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST');
  }

  // Unsupported method (DELETE)
  {
    const response = await handler(
      new Request('http://local/route-cache', {
        method: 'DELETE',
      }),
    );
    assert.equal(response.status, 405);
    const json = await response.json();
    assert.equal(json.error.code, 'ERR_METHOD_NOT_ALLOWED');
  }
});

Deno.test('route-cache handler: supports GET request with query parameters', async () => {
  const mockClient = createMockSupabaseClient((name, params) => {
    assert.equal(name, 'rpc_acquire_price_refresh_lease');
    assert.equal(params.p_origin_iata, 'BKK');
    assert.equal(params.p_destination_iata, 'LON');
    assert.equal(params.p_currency_code, 'EUR');
    assert.equal(params.p_market_code, 'gb');
    return Promise.resolve({
      data: {
        status: 'fresh',
        origin: 'BKK',
        destination: 'LON',
        count: 0,
        observations: [],
      },
      error: null,
    });
  });

  const handler = createRouteCacheHandler({
    getSupabaseClient: () => mockClient,
  });

  const request = new Request(
    'http://local/route-cache?originIata=bkk&destIata=lon&currency=EUR&market=GB&locale=en-GB',
    { method: 'GET' },
  );

  const response = await handler(request);
  assert.equal(response.status, 200);
  const json = await response.json();
  assert.equal(json.error, null);
  assert.equal(json.data.status, 'fresh');
});
