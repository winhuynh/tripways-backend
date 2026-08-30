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

  let rpcCalledWith: { functionName: string; args: Record<string, unknown> } | null = null;

  const mockDbClient: RouteIngestionDbClient = {
    rpc(functionName, args) {
      rpcCalledWith = { functionName, args };
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
    },
    mockDbClient,
  );

  assert.equal(result.status, 'success');
  assert.equal(result.total_airports_processed, 1);
  assert.equal(result.total_routes_upserted, 1);
  assert.equal(result.errors.length, 0);

  assert.ok(rpcCalledWith !== null);
  assert.equal(
    (rpcCalledWith as { functionName: string }).functionName,
    'rpc_ingest_direct_flight_routes',
  );
  assert.equal(
    (rpcCalledWith as { args: { p_source_code: string } }).args.p_source_code,
    'aerodatabox',
  );
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
});
