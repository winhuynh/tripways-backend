import assert from 'node:assert/strict';

const sourceRoot = new URL('../../../../sql_src/', import.meta.url);
async function read(path: string): Promise<string> {
  try {
    return (await Deno.readTextFile(new URL(path, sourceRoot))).toLowerCase();
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return '';
    throw error;
  }
}

Deno.test('schedule services are absent until Tripways has a licensed schedule provider', async () => {
  assert.equal(await read('schema/route_discovery/flight_services.sql'), '');
  assert.equal(await read('functions/route_discovery/calculate_layover_minutes.sql'), '');
});

Deno.test('flight route options are a direct versioned projection without schedule or ranges', async () => {
  const sql = await read('schema/route_discovery/flight_route_options.sql');
  assert.ok(sql.includes('create table public.flight_route_options'));
  assert.ok(sql.includes('publication_version_id'));
  assert.ok(sql.includes('observed_amount'));
  for (
    const removed of [
      'price_min',
      'price_max',
      'days_of_week',
      'layover_minutes',
      'connection_airport_ids',
    ]
  ) {
    assert.equal(sql.includes(removed), false, `${removed} must be absent`);
  }
});

Deno.test('route search reads only the lean route projection', async () => {
  const search = await read('functions/route_discovery/rpc_search_routes.sql');
  const refresh = await read('functions/route_discovery/refresh_route_search_options.sql');
  assert.ok(search.includes('public.flight_route_options'));
  assert.ok(refresh.includes('public.flight_route_prices'));
  assert.equal(refresh.includes('public.flight_routes'), false);
  assert.equal(refresh.includes('public.flight_services'), false);
  assert.equal(refresh.includes('with recursive'), false);
});
