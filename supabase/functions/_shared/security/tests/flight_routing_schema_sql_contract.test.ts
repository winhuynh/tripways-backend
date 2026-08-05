import assert from 'node:assert/strict';

const sourceRoot = new URL('../../../../sql_src/', import.meta.url);
const supabaseConfig = new URL('../../../../config.toml', import.meta.url);

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
  ['schema/flight_routing/data_sources.sql', 'admin.data_sources'],
  ['schema/flight_routing/countries.sql', 'public.countries'],
  ['schema/flight_routing/cities.sql', 'public.cities'],
  ['schema/flight_routing/airports.sql', 'public.airports'],
  ['schema/flight_routing/airlines.sql', 'public.airlines'],
  ['schema/flight_routing/flight_routes.sql', 'public.flight_routes'],
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
  const sql = await readSource('schema/flight_routing/data_sources.sql');

  assert.ok(includesSql(sql, 'environment_scope text not null'));
  assert.ok(includesSql(sql, "check (environment_scope in ('development', 'production'))"));
  assert.ok(includesSql(sql, 'production_allowed boolean not null default false'));
  assert.ok(includesSql(sql, 'seo_allowed boolean not null default false'));
  assert.ok(includesSql(sql, 'derived_data_allowed boolean not null default false'));
});

Deno.test('airports enforce stable codes, coordinates, and supported source values', async () => {
  const sql = await readSource('schema/flight_routing/airports.sql');

  assert.ok(includesSql(sql, "iata ~ '^[A-Z]{3}$'"));
  assert.ok(includesSql(sql, "icao ~ '^[A-Z0-9]{4}$'"));
  assert.ok(includesSql(sql, 'latitude between -90 and 90'));
  assert.ok(includesSql(sql, 'longitude between -180 and 180'));
  assert.ok(includesSql(sql, "'large_airport'"));
  assert.ok(includesSql(sql, "'medium_airport'"));
  assert.ok(includesSql(sql, "'small_airport'"));
  assert.ok(includesSql(sql, 'image_path text null'));
  assert.ok(includesSql(sql, "image_path like 'airports/%'"));
  assert.ok(includesSql(sql, "image_path !~* '^[a-z][a-z0-9+.-]*://'"));
});

Deno.test('airlines classify constrained business models for derived airport stats', async () => {
  const sql = await readSource('schema/flight_routing/airlines.sql');

  assert.ok(includesSql(sql, "business_model text not null default 'unknown'"));
  assert.ok(includesSql(sql, "'full_service'"));
  assert.ok(includesSql(sql, "'low_cost'"));
  assert.ok(includesSql(sql, "'hybrid'"));
  assert.ok(includesSql(sql, "'unknown'"));
  assert.ok(includesSql(sql, 'logo_path text null'));
  assert.ok(includesSql(sql, "logo_path like 'airlines/%'"));
  assert.ok(includesSql(sql, "logo_path !~* '^[a-z][a-z0-9+.-]*://'"));
});

Deno.test('public media bucket restricts stored objects to supported image files', async () => {
  const sql = await readSource('schema/storage/media_bucket.sql');

  assert.ok(includesSql(sql, 'insert into storage.buckets'));
  assert.ok(includesSql(sql, "'media'"));
  assert.ok(includesSql(sql, 'true'));
  assert.ok(includesSql(sql, "'image/jpeg'"));
  assert.ok(includesSql(sql, "'image/png'"));
  assert.ok(includesSql(sql, "'image/webp'"));
  assert.ok(includesSql(sql, "'image/avif'"));
  assert.ok(includesSql(sql, "'image/svg+xml'"));
});

Deno.test('local Supabase enables Storage before applying the media bucket migration', async () => {
  const config = await Deno.readTextFile(supabaseConfig);

  assert.match(config, /\[storage\]\s+enabled\s*=\s*true/);
});

Deno.test('airport page builder exposes airport image and airline logo object paths', async () => {
  const airportPage = await readSource('functions/pseo/airport/build_airport_page_payload.sql');

  assert.ok(includesSql(airportPage, "'image_path', airport.image_path"));
  assert.ok(includesSql(airportPage, 'airline.logo_path'));
});

Deno.test('flight routes enforce direction, source lineage, confidence, and unknown-safe fields', async () => {
  const sql = await readSource('schema/flight_routing/flight_routes.sql');

  assert.ok(includesSql(sql, 'origin_airport_id <> destination_airport_id'));
  assert.ok(includesSql(sql, 'unique (source_id, source_record_id)'));
  assert.ok(includesSql(sql, 'confidence_score between 0 and 1'));
  assert.ok(includesSql(sql, 'frequency_per_week numeric(6, 2)'));
  assert.ok(includesSql(sql, "seasonality text not null default 'unknown'"));
  assert.ok(includesSql(sql, "'verified_active'"));
  assert.ok(includesSql(sql, "'low_confidence'"));
  assert.equal(includesSql(sql, 'frequency_per_week numeric(6, 2) not null'), false);
});
