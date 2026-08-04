import assert from 'node:assert/strict';

const sourceRoot = new URL('../../../../sql_src/', import.meta.url);

async function readSource(relativePath: string): Promise<string> {
  try {
    return await Deno.readTextFile(new URL(relativePath, sourceRoot));
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return '';
    throw error;
  }
}

function includesSql(sql: string, fragment: string): boolean {
  const normalize = (value: string) => value.replace(/\s+/g, ' ').trim().toLowerCase();
  return normalize(sql).includes(normalize(fragment));
}

Deno.test('flight services preserve schedule patterns and source lineage', async () => {
  const sql = await readSource('schema/route_discovery/flight_services.sql');

  assert.ok(includesSql(sql, 'create table public.flight_services'));
  assert.equal((sql.match(/create table /gi) ?? []).length, 1);
  assert.ok(
    includesSql(sql, 'flight_route_id uuid not null references public.flight_routes (id)'),
  );
  assert.ok(includesSql(sql, 'flight_number text not null'));
  assert.ok(includesSql(sql, 'valid_from date not null'));
  assert.ok(includesSql(sql, 'valid_to date not null'));
  assert.ok(includesSql(sql, 'days_of_week smallint[] not null'));
  assert.ok(includesSql(sql, 'departure_local_time time not null'));
  assert.ok(includesSql(sql, 'arrival_local_time time not null'));
  assert.ok(includesSql(sql, 'arrival_day_offset smallint not null'));
  assert.ok(includesSql(sql, 'duration_minutes integer not null'));
  assert.ok(includesSql(sql, 'source_id uuid not null references admin.data_sources (id)'));
  assert.ok(includesSql(sql, 'unique (source_id, source_record_id)'));
});

Deno.test('flight services enforce bounded schedules and confidence', async () => {
  const sql = await readSource('schema/route_discovery/flight_services.sql');

  assert.ok(includesSql(sql, 'valid_from <= valid_to'));
  assert.ok(includesSql(sql, 'cardinality(days_of_week) between 1 and 7'));
  assert.ok(
    includesSql(sql, 'days_of_week <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]'),
  );
  assert.ok(includesSql(sql, 'arrival_day_offset between 0 and 2'));
  assert.ok(includesSql(sql, 'duration_minutes between 1 and 1440'));
  assert.ok(includesSql(sql, 'confidence_score between 0 and 1'));
});

Deno.test('flight services are closed to public clients', async () => {
  const sql = await readSource('schema/route_discovery/flight_services.sql');

  assert.ok(
    includesSql(sql, 'alter table public.flight_services enable row level security'),
  );
  assert.ok(
    includesSql(sql, 'revoke all on table public.flight_services from anon, authenticated'),
  );
  assert.ok(
    includesSql(
      sql,
      'grant select, insert, update, delete on table public.flight_services to service_role',
    ),
  );
});

Deno.test('route options keep one read model table with closed client access', async () => {
  const sql = await readSource('schema/route_discovery/route_options.sql');

  assert.ok(includesSql(sql, 'create table public.route_options'));
  assert.equal((sql.match(/create table /gi) ?? []).length, 1);
  assert.ok(includesSql(sql, 'stop_count smallint not null'));
  assert.ok(includesSql(sql, 'service_ids uuid[] not null'));
  assert.ok(includesSql(sql, 'flight_route_ids uuid[] not null'));
  assert.ok(includesSql(sql, 'origin_airport_ids uuid[] not null'));
  assert.ok(includesSql(sql, 'destination_airport_ids uuid[] not null'));
  assert.ok(includesSql(sql, 'connection_airport_ids uuid[] not null'));
  assert.ok(includesSql(sql, 'layover_minutes_by_connection integer[] not null'));
  assert.ok(includesSql(sql, 'stop_count between 0 and 3'));
  assert.ok(includesSql(sql, 'total_duration_minutes integer not null'));
  assert.ok(includesSql(sql, 'data_version uuid not null'));
  assert.ok(includesSql(sql, 'alter table public.route_options enable row level security'));
  assert.ok(includesSql(sql, 'revoke all on table public.route_options from anon, authenticated'));
});

Deno.test('route refresh uses bounded recursive expansion for up to three stops', async () => {
  const sql = await readSource('functions/route_discovery/refresh_route_options.sql');

  assert.ok(includesSql(sql, 'with recursive route_paths'));
  assert.ok(includesSql(sql, 'cardinality(path.service_ids) < 4'));
  assert.ok(includesSql(sql, 'not (next_route.destination_airport_id = any(path.airport_path))'));
  assert.ok(includesSql(sql, 'connection.layover_minutes between 45 and 1440'));
});

for (
  const functionName of [
    'calculate_layover_minutes',
    'refresh_route_options',
    'rpc_search_route_options_v2',
  ]
) {
  Deno.test(`${functionName} has an isolated source file and explicit search path`, async () => {
    const sql = await readSource(
      `functions/route_discovery/${functionName}.sql`,
    );

    assert.equal((sql.match(/create or replace function /gi) ?? []).length, 1);
    assert.ok(includesSql(sql, `function public.${functionName}`));
    assert.ok(includesSql(sql, "set search_path = ''"));
  });
}

Deno.test('route search RPC owns validation, filters, facets, and stable errors', async () => {
  const sql = await readSource(
    'functions/route_discovery/rpc_search_route_options_v2.sql',
  );

  assert.ok(includesSql(sql, "'ERR_INVALID_REQUEST'"));
  assert.ok(includesSql(sql, "'ERR_ROUTE_DISCOVERY_UNAVAILABLE'"));
  assert.ok(includesSql(sql, "'max_stops'"));
  assert.ok(includesSql(sql, "'max_duration_minutes'"));
  assert.ok(includesSql(sql, "'max_layover_minutes'"));
  assert.ok(includesSql(sql, "'connection_airports'"));
  assert.ok(includesSql(sql, "'facets'"));
  assert.ok(includesSql(sql, 'order by filtered.stop_count'));
  assert.ok(
    includesSql(
      sql,
      'grant execute on function public.rpc_search_route_options_v2(jsonb) to service_role',
    ),
  );
});
