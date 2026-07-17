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

const expectedTables = [
  ['schema/admin/data_sources.sql', 'admin.data_sources'],
  ['schema/public/countries.sql', 'public.countries'],
  ['schema/public/cities.sql', 'public.cities'],
  ['schema/public/airports.sql', 'public.airports'],
  ['schema/public/airlines.sql', 'public.airlines'],
  ['schema/public/flight_routes.sql', 'public.flight_routes'],
] as const;

Deno.test('flight routing keeps one table per schema source file', async () => {
  for (const [path, qualifiedTable] of expectedTables) {
    const sql = await readSource(path);
    assert.ok(
      includesSql(sql, `create table ${qualifiedTable}`),
      `${path} must define ${qualifiedTable}`,
    );
    assert.equal(
      (sql.match(/create table /gi) ?? []).length,
      1,
      `${path} must define exactly one table`,
    );
  }
});

Deno.test('public flight routing tables enable RLS and expose no client writes', async () => {
  for (const [path, qualifiedTable] of expectedTables.slice(1)) {
    const sql = await readSource(path);
    assert.ok(includesSql(sql, `alter table ${qualifiedTable} enable row level security`));
    assert.ok(includesSql(sql, `revoke all on table ${qualifiedTable} from anon, authenticated`));
    assert.equal(includesSql(sql, 'grant insert'), false);
  }
});

Deno.test('data sources record environment and license capabilities', async () => {
  const sql = await readSource('schema/admin/data_sources.sql');

  assert.ok(includesSql(sql, 'environment_scope text not null'));
  assert.ok(includesSql(sql, "check (environment_scope in ('development', 'production'))"));
  assert.ok(includesSql(sql, 'production_allowed boolean not null default false'));
  assert.ok(includesSql(sql, 'seo_allowed boolean not null default false'));
  assert.ok(includesSql(sql, 'derived_data_allowed boolean not null default false'));
});

Deno.test('airports enforce stable codes, coordinates, and supported source values', async () => {
  const sql = await readSource('schema/public/airports.sql');

  assert.ok(includesSql(sql, "iata ~ '^[A-Z]{3}$'"));
  assert.ok(includesSql(sql, "icao ~ '^[A-Z0-9]{4}$'"));
  assert.ok(includesSql(sql, 'latitude between -90 and 90'));
  assert.ok(includesSql(sql, 'longitude between -180 and 180'));
  assert.ok(includesSql(sql, "'large_airport'"));
  assert.ok(includesSql(sql, "'medium_airport'"));
  assert.ok(includesSql(sql, "'small_airport'"));
});

Deno.test('flight routes enforce direction, source lineage, confidence, and unknown-safe fields', async () => {
  const sql = await readSource('schema/public/flight_routes.sql');

  assert.ok(includesSql(sql, 'origin_airport_id <> destination_airport_id'));
  assert.ok(includesSql(sql, 'unique (source_id, source_record_id)'));
  assert.ok(includesSql(sql, 'confidence_score between 0 and 1'));
  assert.ok(includesSql(sql, 'frequency_per_week numeric(6, 2)'));
  assert.ok(includesSql(sql, "seasonality text not null default 'unknown'"));
  assert.ok(includesSql(sql, "'verified_active'"));
  assert.ok(includesSql(sql, "'low_confidence'"));
  assert.equal(includesSql(sql, 'frequency_per_week numeric(6, 2) not null'), false);
});
