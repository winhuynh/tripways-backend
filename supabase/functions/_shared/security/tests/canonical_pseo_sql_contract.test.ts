import assert from 'node:assert/strict';

const repositoryRoot = new URL('../../../../../', import.meta.url);
const sourceRoot = new URL('supabase/sql_src/', repositoryRoot);

async function readSource(relativePath: string): Promise<string> {
  try {
    return await Deno.readTextFile(new URL(relativePath, sourceRoot));
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return '';
    throw error;
  }
}

function normalize(value: string): string {
  return value.replace(/\s+/g, ' ').trim().toLowerCase();
}

async function collectFiles(directory: URL): Promise<URL[]> {
  const files: URL[] = [];
  for await (const entry of Deno.readDir(directory)) {
    const url = new URL(entry.name, directory);
    if (entry.isDirectory) files.push(...await collectFiles(new URL(`${url.href}/`)));
    if (entry.isFile) files.push(url);
  }
  return files;
}

const typedTables = [
  ['schema/pseo/homepage/homepage_pages.sql', 'homepage_pages'],
  ['schema/pseo/homepage/homepage_featured_origins.sql', 'homepage_featured_origins'],
  ['schema/pseo/homepage/homepage_featured_routes.sql', 'homepage_featured_routes'],
  ['schema/pseo/homepage/homepage_content_sections.sql', 'homepage_content_sections'],
  ['schema/pseo/homepage/homepage_faqs.sql', 'homepage_faqs'],
  ['schema/pseo/city/city_content_sections.sql', 'city_content_sections'],
  ['schema/pseo/airport/airport_content_sections.sql', 'airport_content_sections'],
] as const;

Deno.test('each required page content table has one definition and closed client access', async () => {
  for (const [path, table] of typedTables) {
    const sql = normalize(await readSource(path));
    assert.ok(sql.includes(`create table public.${table}`), path);
    assert.equal((sql.match(/create table /g) ?? []).length, 1, path);
    assert.ok(sql.includes(`alter table public.${table} enable row level security`), path);
    assert.ok(sql.includes(`revoke all on table public.${table} from anon, authenticated`), path);
    assert.ok(sql.includes(`to service_role`), path);
  }
});

Deno.test('canonical page and route RPCs are service-role-only functions', async () => {
  for (
    const [path, name] of [
      ['functions/pseo/shared/rpc_get_page.sql', 'rpc_get_page'],
      ['functions/route_discovery/rpc_search_routes.sql', 'rpc_search_routes'],
    ] as const
  ) {
    const sql = normalize(await readSource(path));
    assert.equal((sql.match(/create or replace function /g) ?? []).length, 1, path);
    assert.ok(sql.includes(`function public.${name}(p_input jsonb)`), path);
    assert.ok(sql.includes("set search_path = ''"), path);
    assert.ok(
      sql.includes(`revoke all on function public.${name}(jsonb) from public, anon, authenticated`),
      path,
    );
    assert.ok(
      sql.includes(`grant execute on function public.${name}(jsonb) to service_role`),
      path,
    );
  }
});

Deno.test('published route projection supports geography and one-way price filters', async () => {
  const sql = normalize(await readSource('schema/route_discovery/route_search_options.sql'));
  for (
    const field of [
      'origin_country_code',
      'destination_country_code',
      'destination_region_code',
      'is_international',
      'departure_time_bucket',
      'price_trip_type',
    ]
  ) {
    assert.ok(sql.includes(field), field);
  }
  assert.ok(sql.includes("price_trip_type = 'one_way'"));
});

Deno.test('pSEO SQL source and Edge entrypoints contain no duplicate legacy public RPC names', async () => {
  const roots = [
    new URL('supabase/sql_src/functions/', repositoryRoot),
    new URL('supabase/functions/v1/page/', repositoryRoot),
    new URL('supabase/functions/v1/route-search/', repositoryRoot),
  ];
  const files = (await Promise.all(roots.map(collectFiles))).flat();
  const source = normalize(
    (await Promise.all(files.map((file) => Deno.readTextFile(file)))).join('\n'),
  );
  const legacyNames = [
    'rpc_get_page_v2',
    'rpc_search_route_options_v2',
    'rpc_search_route_options',
    'rpc_get_homepage_discovery',
    'rpc_get_city_page',
    'rpc_get_airport_page',
    'rpc_get_route_page',
    'rpc_get_city_overview',
    'rpc_get_city_airports',
    'rpc_get_city_airlines',
    'rpc_get_city_faqs',
    'rpc_get_city_insights',
    'rpc_get_city_internal_links',
    'rpc_get_city_quick_facts',
    'rpc_get_city_route_map',
  ];
  for (const name of legacyNames) assert.equal(source.includes(name), false, name);
});

Deno.test('airport page source uses a journey-led payload instead of legacy featured routes', async () => {
  const pageSql = normalize(
    await readSource('functions/pseo/airport/build_airport_page_payload.sql'),
  );
  const journeySql = normalize(
    await readSource('schema/pseo/airport/airport_journey_steps.sql'),
  );

  assert.ok(journeySql.includes('create table public.airport_journey_steps'));
  assert.ok(journeySql.includes("journey_type in ('arrival', 'departure')"));
  assert.ok(journeySql.includes("audience in ('all', 'domestic', 'international')"));
  for (
    const key of [
      "'orientation'",
      "'quick_answers'",
      "'arrival'",
      "'departure'",
      "'transport'",
      "'provenance'",
    ]
  ) {
    assert.ok(pageSql.includes(key), key);
  }
  for (
    const legacyKey of [
      "'featured_outbound_routes'",
      "'featured_inbound_routes'",
      "'price_summary'",
    ]
  ) {
    assert.equal(pageSql.includes(legacyKey), false, legacyKey);
  }
});

Deno.test('route page read model excludes interactive route-search results', async () => {
  const sql = normalize(
    await readSource('functions/pseo/route/build_route_page_payload.sql'),
  );

  assert.equal(sql.includes("'options', public.rpc_search_routes"), false);
  assert.ok(sql.includes("'summary', jsonb_build_object"));
});

Deno.test('canonical route search supports direct-only airport scope in both directions', async () => {
  const sql = normalize(await readSource('functions/route_discovery/rpc_search_routes.sql'));

  assert.ok(sql.includes("v_scope_type = 'airport'"));
  assert.ok(sql.includes("v_airport_direction in ('from', 'to')"));
  assert.ok(sql.includes("v_scope_type <> 'airport' or option.stop_count = 0"));
  assert.ok(
    sql.includes(
      "v_airport_direction <> 'from' or option.origin_airport_iata = upper(v_scope_key)",
    ),
  );
  assert.ok(
    sql.includes(
      "v_airport_direction <> 'to' or option.destination_airport_iata = upper(v_scope_key)",
    ),
  );
  assert.ok(sql.includes("'counterpart_query'"));
});
