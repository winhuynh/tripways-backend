import assert from 'node:assert/strict';
import { ingestDirectRoutesForAirports, type RouteIngestionDbClient } from '../service.ts';

Deno.test('ingestDirectRoutesForAirports batch processes airports and calls rpc', async () => {
  const samplePayload = {
    routes: [
      {
        destination: { iata: 'SIN' },
        airline: { iata: 'SQ', name: 'Singapore Airlines' },
        flightNumbers: ['SQ173'],
        operatingDays: [1, 2, 3, 4, 5, 6, 7],
        duration: 'PT2H05M',
        distanceKm: 1085,
      },
    ],
  };

  const mockFetch: typeof fetch = (_input, _init) => {
    return Promise.resolve(
      new Response(JSON.stringify(samplePayload), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  };

  const rpcCalls: { functionName: string; args: Record<string, unknown> }[] = [];

  const mockDbClient: RouteIngestionDbClient = {
    rpc(functionName, args) {
      rpcCalls.push({ functionName, args });
      if (functionName === 'rpc_purge_expired_direct_flight_routes') {
        return Promise.resolve({
          data: { status: 'success', source_code: 'aerodatabox', deleted_count: 3 },
          error: null,
        });
      }
      return Promise.resolve({
        data: { status: 'success', upserted_count: 1 },
        error: null,
      });
    },
  };

  const result = await ingestDirectRoutesForAirports(
    ['SGN'],
    {
      apiKey: 'test-key-12345678',
      fetchFn: mockFetch,
      delayMs: 0,
    },
    mockDbClient,
  );

  assert.equal(result.status, 'success');
  assert.equal(result.total_airports_processed, 1);
  assert.equal(result.total_routes_upserted, 1);
  assert.equal(result.total_routes_purged, 3);
  assert.equal(result.errors.length, 0);

  const ingestCall = rpcCalls.find((c) => c.functionName === 'rpc_ingest_direct_flight_routes');
  assert.ok(ingestCall !== undefined);
  assert.equal(ingestCall?.args.p_source_code, 'aerodatabox');

  const purgeCall = rpcCalls.find((c) =>
    c.functionName === 'rpc_purge_expired_direct_flight_routes'
  );
  assert.ok(purgeCall !== undefined);
  assert.equal(purgeCall?.args.p_source_code, 'aerodatabox');
  assert.equal(purgeCall?.args.p_retention_interval, '7 days');
});

Deno.test('ingestDirectRoutesForAirports handles empty or invalid airport lists gracefully', async () => {
  const mockDbClient: RouteIngestionDbClient = {
    rpc() {
      return Promise.resolve({ data: null, error: null });
    },
  };

  const result = await ingestDirectRoutesForAirports(
    ['', 'INVALID_IATA'],
    { apiKey: 'test-key-12345678' },
    mockDbClient,
  );

  assert.equal(result.status, 'success');

  assert.equal(result.total_airports_processed, 0);
  assert.equal(result.total_routes_upserted, 0);
  assert.equal(result.total_routes_purged, 0);
});
