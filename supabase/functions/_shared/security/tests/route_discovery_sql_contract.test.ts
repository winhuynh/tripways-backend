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

Deno.test('flight route options store pre-computed 0-stop and 1-stop route graph projection', async () => {
  const sql = await read('schema/route_discovery/flight_route_options.sql');
  assert.ok(sql.includes('create table public.flight_route_options'));
  assert.ok(sql.includes('publication_version_id'));
  assert.ok(sql.includes('stops'));
  assert.ok(sql.includes('layover_airports'));
  assert.ok(sql.includes('operating_airlines'));
  assert.ok(sql.includes('total_duration_minutes'));
  assert.ok(sql.includes('days_of_week'));
  assert.ok(sql.includes('departure_time_buckets'));
  assert.ok(sql.includes('layover_minutes'));
  assert.ok(sql.includes('price_amount'));
  assert.ok(sql.includes('destination_region'));
  assert.ok(sql.includes('cabins'));
  assert.ok(sql.includes('route_type'));
});

Deno.test('route calculation helpers are modular, pure, and security-isolated', async () => {
  const dist = await read('functions/route_discovery/calculate_haversine_distance_km.sql');
  assert.ok(dist.includes('create or replace function admin.calculate_haversine_distance_km'));
  assert.ok(dist.includes('immutable'));
  assert.ok(dist.includes('returns integer'));

  const sched = await read('functions/route_discovery/calculate_route_schedule_intersection.sql');
  assert.ok(
    sched.includes('create or replace function admin.calculate_route_schedule_intersection'),
  );
  assert.ok(sched.includes('immutable'));
  assert.ok(sched.includes('returns integer[]'));

  const dur = await read('functions/route_discovery/calculate_connecting_duration_minutes.sql');
  assert.ok(dur.includes('create or replace function admin.calculate_connecting_duration_minutes'));
  assert.ok(dur.includes('immutable'));
  assert.ok(dur.includes('returns integer'));

  const cls = await read('functions/route_discovery/classify_route_connection_type.sql');
  assert.ok(cls.includes('create or replace function admin.classify_route_connection_type'));
  assert.ok(cls.includes('immutable'));
  assert.ok(cls.includes('returns text'));
});

Deno.test('route search reads from pre-computed flight_route_options', async () => {
  const search = await read('functions/route_discovery/rpc_search_routes.sql');
  const refresh = await read('functions/route_discovery/refresh_route_search_options.sql');
  assert.ok(search.includes('public.flight_route_options'));
  assert.ok(refresh.includes('public.direct_flight_routes'));
  assert.ok(refresh.includes('public.flight_route_options'));
  assert.ok(refresh.includes('admin.calculate_connecting_duration_minutes'));
  assert.ok(refresh.includes('admin.calculate_route_schedule_intersection'));
  assert.ok(refresh.includes('admin.classify_route_connection_type'));
  assert.ok(refresh.includes('admin.calculate_haversine_distance_km'));
  assert.ok(search.includes("'total'"));
  assert.ok(search.includes("'facets'"));
  assert.ok(search.includes("'next_cursor'"));
  assert.ok(search.includes("'price'"));
});
