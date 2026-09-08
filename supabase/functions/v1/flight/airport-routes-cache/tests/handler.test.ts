import assert from 'node:assert/strict';
import type { SupabaseClient } from '@supabase/supabase-js';
import { createAirportRoutesCacheHandler } from '../handler.ts';
import type {
  AeroDataBoxConfig,
  AeroDataBoxRoute,
} from '../../../ingestion/routes/providers/aerodatabox-provider.ts';

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

Deno.test('airport-routes-cache handler: cache hit (fresh) returns status immediately without calling provider', async () => {
  let providerCalled = false;

  const mockClient = createMockSupabaseClient((name, params) => {
    assert.equal(name, 'rpc_acquire_airport_route_refresh_lease');
    assert.equal(params.p_origin_iata, 'VCL');
    return Promise.resolve({
      data: {
        status: 'fresh',
        origin: 'VCL',
        count: 2,
      },
      error: null,
    });
  });

  const fetchRoutes = (_iata: string, _config: AeroDataBoxConfig): Promise<AeroDataBoxRoute[]> => {
    providerCalled = true;
    return Promise.resolve([]);
  };

  const handler = createAirportRoutesCacheHandler({
    getSupabaseClient: () => mockClient,
    fetchRoutes,
  });

  const request = new Request(
    'http://localhost/functions/v1/flight/airport-routes-cache?origin=VCL',
    {
      method: 'GET',
    },
  );

  const response = await handler(request);
  assert.equal(response.status, 200);

  const body = await response.json();
  assert.equal(body.error, null);
  assert.equal(body.data.status, 'fresh');
  assert.equal(body.data.origin, 'VCL');
  assert.equal(body.data.count, 2);
  assert.equal(providerCalled, false);
});

Deno.test('airport-routes-cache handler: lease acquired calls AeroDataBox and ingests routes', async () => {
  let providerCalled = false;
  const rpcCalls: { name: string; params: Record<string, unknown> }[] = [];

  const mockRoutes: AeroDataBoxRoute[] = [
    {
      origin_iata: 'VCL',
      destination_iata: 'SGN',
      airline_iata: 'VN',
      airline_name: 'Vietnam Airlines',
      flight_numbers: ['VN1461'],
      flight_duration_minutes: 75,
      distance_km: 600,
      days_of_week: [1, 2, 3, 4, 5, 6, 7],
      aircraft_types: ['A321'],
      source_record_id: 'aerodatabox-VCL-SGN-VN',
    },
  ];

  const mockClient = createMockSupabaseClient((name, params) => {
    rpcCalls.push({ name, params });
    if (name === 'rpc_acquire_airport_route_refresh_lease') {
      return Promise.resolve({
        data: {
          status: 'lease_acquired',
          origin: 'VCL',
          lease_id: '123e4567-e89b-12d3-a456-426614174000',
        },
        error: null,
      });
    }
    if (name === 'rpc_ingest_direct_flight_routes') {
      return Promise.resolve({
        data: { status: 'success', upserted_count: 1 },
        error: null,
      });
    }
    if (name === 'rpc_finalize_airport_route_refresh_lease') {
      return Promise.resolve({
        data: { status: 'success', origin: 'VCL', lease_status: 'fresh' },
        error: null,
      });
    }
    return Promise.resolve({ data: null, error: null });
  });

  const fetchRoutes = (iata: string, _config: AeroDataBoxConfig): Promise<AeroDataBoxRoute[]> => {
    providerCalled = true;
    assert.equal(iata, 'VCL');
    return Promise.resolve(mockRoutes);
  };

  const handler = createAirportRoutesCacheHandler({
    getSupabaseClient: () => mockClient,
    fetchRoutes,
  });

  const request = new Request('http://localhost/functions/v1/flight/airport-routes-cache', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ origin: 'VCL' }),
  });

  const response = await handler(request);
  assert.equal(response.status, 200);

  const body = await response.json();
  assert.equal(body.error, null);
  assert.equal(body.data.status, 'fresh');
  assert.equal(body.data.origin, 'VCL');
  assert.equal(body.data.routes_count, 1);
  assert.equal(providerCalled, true);

  const ingestCall = rpcCalls.find((c) => c.name === 'rpc_ingest_direct_flight_routes');
  assert.ok(ingestCall !== undefined);
  assert.equal(ingestCall?.params.p_source_code, 'aerodatabox');

  const finalizeCall = rpcCalls.find((c) => c.name === 'rpc_finalize_airport_route_refresh_lease');
  assert.ok(finalizeCall !== undefined);
  assert.equal(finalizeCall?.params.p_status, 'fresh');
});

Deno.test('airport-routes-cache handler: unknown airport returns 404', async () => {
  const mockClient = createMockSupabaseClient((name, _params) => {
    assert.equal(name, 'rpc_acquire_airport_route_refresh_lease');
    return Promise.resolve({
      data: {
        status: 'failed',
        error: 'ERR_UNKNOWN_AIRPORT',
      },
      error: null,
    });
  });

  const handler = createAirportRoutesCacheHandler({
    getSupabaseClient: () => mockClient,
  });

  const request = new Request(
    'http://localhost/functions/v1/flight/airport-routes-cache?origin=ZZZ',
    {
      method: 'GET',
    },
  );

  const response = await handler(request);
  assert.equal(response.status, 404);

  const body = await response.json();
  assert.equal(body.error?.code, 'ERR_AIRPORT_ROUTES_CACHE_UNKNOWN_AIRPORT');
});

Deno.test('airport-routes-cache handler: cooldown returns empty response', async () => {
  const mockClient = createMockSupabaseClient((name, _params) => {
    assert.equal(name, 'rpc_acquire_airport_route_refresh_lease');
    return Promise.resolve({
      data: {
        status: 'cooldown',
        origin: 'VCL',
        next_allowed_refresh_at: '2026-09-09T00:00:00Z',
      },
      error: null,
    });
  });

  const handler = createAirportRoutesCacheHandler({
    getSupabaseClient: () => mockClient,
  });

  const request = new Request(
    'http://localhost/functions/v1/flight/airport-routes-cache?origin=VCL',
    {
      method: 'GET',
    },
  );

  const response = await handler(request);
  assert.equal(response.status, 200);

  const body = await response.json();
  assert.equal(body.error, null);
  assert.equal(body.data.status, 'empty');
  assert.equal(body.data.origin, 'VCL');
  assert.equal(body.data.routes_count, 0);
});

Deno.test('airport-routes-cache handler: provider failure finalizes as failed and returns 503', async () => {
  const rpcCalls: { name: string; params: Record<string, unknown> }[] = [];

  const mockClient = createMockSupabaseClient((name, params) => {
    rpcCalls.push({ name, params });
    if (name === 'rpc_acquire_airport_route_refresh_lease') {
      return Promise.resolve({
        data: {
          status: 'lease_acquired',
          origin: 'VCL',
          lease_id: 'test-lease-id',
        },
        error: null,
      });
    }
    if (name === 'rpc_finalize_airport_route_refresh_lease') {
      return Promise.resolve({
        data: { status: 'success' },
        error: null,
      });
    }
    return Promise.resolve({ data: null, error: null });
  });

  const fetchRoutes = (): Promise<AeroDataBoxRoute[]> => {
    return Promise.reject(
      new Error('Provider timeout error with a very long message explaining upstream failure'),
    );
  };

  const handler = createAirportRoutesCacheHandler({
    getSupabaseClient: () => mockClient,
    fetchRoutes,
  });

  const request = new Request('http://localhost/functions/v1/flight/airport-routes-cache', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ origin: 'VCL' }),
  });

  const response = await handler(request);
  assert.equal(response.status, 503);

  const body = await response.json();
  assert.equal(body.error?.code, 'ERR_AIRPORT_ROUTES_CACHE_UNAVAILABLE');

  const finalizeCall = rpcCalls.find((c) => c.name === 'rpc_finalize_airport_route_refresh_lease');
  assert.ok(finalizeCall !== undefined);
  assert.equal(finalizeCall?.params.p_status, 'failed');
  assert.equal(finalizeCall?.params.p_lease_token, 'test-lease-id');
  // Check failure code is truncated to <= 50 chars
  assert.ok(typeof finalizeCall?.params.p_failure_code === 'string');
  assert.ok((finalizeCall?.params.p_failure_code as string).length <= 50);
});
