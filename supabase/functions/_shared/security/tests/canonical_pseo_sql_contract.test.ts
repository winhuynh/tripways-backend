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
  ['schema/pseo/city/city_content_sections.sql', 'city_content_sections'],
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

Deno.test('homepage is a landing page backed only by canonical search and statistics', async () => {
  for (
    const path of [
      'schema/pseo/homepage/homepage_pages.sql',
      'schema/pseo/homepage/homepage_featured_origins.sql',
      'schema/pseo/homepage/homepage_featured_routes.sql',
      'schema/pseo/homepage/homepage_content_sections.sql',
      'schema/pseo/homepage/homepage_faqs.sql',
      'schema/pseo/homepage/homepage_read_models.sql',
      'functions/pseo/homepage/build_homepage_discovery.sql',
    ]
  ) {
    assert.equal(await readSource(path), '', path);
  }

  const statsSql = normalize(
    await readSource('functions/pseo/homepage/rpc_get_homepage_statistics.sql'),
  );
  const statsTableSql = normalize(
    await readSource('schema/pseo/homepage/homepage_statistics.sql'),
  );
  const refreshStatsSql = normalize(
    await readSource('functions/pseo/homepage/refresh_homepage_statistics.sql'),
  );
  assert.ok(statsTableSql.includes('create table public.homepage_statistics'));
  assert.ok(
    statsTableSql.includes('alter table public.homepage_statistics enable row level security'),
  );
  assert.ok(statsTableSql.includes('create policy homepage_statistics_public_read'));
  assert.ok(
    statsTableSql.includes(
      'grant select on table public.homepage_statistics to anon, authenticated',
    ),
  );
  assert.ok(refreshStatsSql.includes('function private.refresh_homepage_statistics'));
  assert.ok(refreshStatsSql.includes('count(distinct option.origin_city_id)'));
  assert.ok(refreshStatsSql.includes('count(distinct option.origin_airport_id)'));
  assert.ok(refreshStatsSql.includes('count(distinct option.route_path)'));
  assert.ok(statsSql.includes('function public.rpc_get_homepage_statistics()'));
  assert.ok(statsSql.includes('from public.homepage_statistics statistics'));
  assert.ok(statsSql.includes("set search_path = ''"));
  assert.ok(
    statsSql.includes(
      'revoke all on function public.rpc_get_homepage_statistics() from public',
    ),
  );
  assert.ok(
    statsSql.includes(
      'grant execute on function public.rpc_get_homepage_statistics() to anon, authenticated, service_role',
    ),
  );

  const config = normalize(
    await Deno.readTextFile(new URL('supabase/config.toml', repositoryRoot)),
  );
  assert.equal(config.includes('[functions.homepage-statistics]'), false);
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

Deno.test('pSEO pages and route search share one canonical publication projection', async () => {
  const [cityPageSql, airportPageSql, routePageSql, publisherSql] = await Promise.all([
    readSource('functions/pseo/city/build_city_page_payload.sql'),
    readSource('functions/pseo/airport/build_airport_page_payload.sql'),
    readSource('functions/pseo/route/build_route_page_payload.sql'),
    readSource('functions/pseo/shared/publish_read_model_version.sql'),
  ]);

  for (const source of [cityPageSql, airportPageSql, routePageSql]) {
    const sql = normalize(source);
    assert.ok(sql.includes('public.route_search_options'));
    assert.equal(sql.includes('public.pseo_direct_routes'), false);
    assert.equal(sql.includes('public.route_options'), false);
  }

  const publisher = normalize(publisherSql);
  assert.ok(publisher.includes('private.refresh_route_search_options'));
  assert.ok(publisher.includes('private.refresh_page_read_models'));
  assert.equal(publisher.includes('refresh_pseo_read_models'), false);
});

Deno.test('homepage place and origin search read only the current canonical projection', async () => {
  for (const path of [
    'functions/pseo/homepage/rpc_search_places.sql',
    'functions/pseo/homepage/rpc_resolve_homepage_origin.sql',
  ]) {
    const sql = normalize(await readSource(path));
    assert.ok(sql.includes('public.publication_versions'), path);
    assert.ok(sql.includes('public.route_search_options'), path);
    assert.equal(sql.includes('public.route_options'), false, path);
    assert.equal(sql.includes('city.slug'), false, path);
  }
});

Deno.test('city page identity resolves canonical page slug before normalized city', async () => {
  const sql = normalize(
    await readSource('functions/pseo/city/resolve_city_page_context.sql'),
  );
  const pageLookup = sql.indexOf('from public.city_pages');
  const cityLookup = sql.indexOf('from public.cities');
  assert.ok(pageLookup >= 0);
  assert.ok(cityLookup < 0 || pageLookup < cityLookup);
  assert.ok(sql.includes('registry.entity_key = p_city_slug'));
});

Deno.test('city slug rename E2E restores the production canonical slug after verification', async () => {
  const sql = normalize(
    await Deno.readTextFile(new URL('supabase/snippets/e2e_city_slug_rename.sql', repositoryRoot)),
  );
  assert.ok(sql.includes("private.rename_city_slug('bangkok', 'bangkok-thailand')"));
  assert.ok(sql.includes("private.rename_city_slug('bangkok-thailand', 'bangkok')"));
  assert.ok(sql.includes("entity_key', 'bangkok'"));
  assert.ok(sql.includes("entity_key', 'bangkok-thailand'"));
});

Deno.test('legacy route and city projection sources are removed from migration inputs', async () => {
  const legacySources = [
    'schema/pseo/shared/pseo_direct_routes.sql',
    'schema/pseo/city/city_destination_summaries.sql',
    'schema/route_discovery/route_options.sql',
    'functions/pseo/shared/refresh_pseo_read_models.sql',
    'functions/route_discovery/refresh_route_options.sql',
    'functions/pseo/city/get_city_airport_route_stats.sql',
    'functions/pseo/city/get_city_quick_facts.sql',
    'functions/pseo/city/get_city_route_map.sql',
  ];
  for (const source of legacySources) {
    assert.equal(await readSource(source), '', source);
  }
});

Deno.test('page subtype tables contain editorial content but no canonical lifecycle copies', async () => {
  for (const source of [
    'schema/pseo/city/city_pages.sql',
    'schema/pseo/airport/airport_pages.sql',
    'schema/pseo/route/route_pages.sql',
  ]) {
    const sql = normalize(await readSource(source));
    for (const duplicate of [
      'canonical_slug',
      'is_indexable',
      'noindex_reason',
      'data_version',
      'source_freshness_at',
      'generated_at',
    ]) {
      assert.equal(sql.includes(duplicate), false, `${source}: ${duplicate}`);
    }
  }
});

Deno.test('airport journey schema removes legacy content stores and keeps directional utility fields', async () => {
  const airportFactsSql = await readSource('schema/pseo/airport/airport_facts.sql');
  const airportSectionsSql = await readSource(
    'schema/pseo/airport/airport_content_sections.sql',
  );
  const accessSql = normalize(
    await readSource('schema/pseo/airport/airport_access_options.sql'),
  );
  const loungeSql = normalize(await readSource('schema/pseo/airport/airport_lounges.sql'));

  assert.equal(airportFactsSql, '');
  assert.equal(airportSectionsSql, '');
  for (
    const field of [
      'journey_direction',
      'pickup_location_summary',
      'best_for_label',
      'luggage_summary',
      'accessibility_summary',
    ]
  ) {
    assert.ok(accessSql.includes(field), field);
  }
  for (
    const field of [
      'operating_hours_summary',
      'estimated_price_min',
      'estimated_price_max',
      'currency_code',
      'affiliate_url',
    ]
  ) {
    assert.ok(loungeSql.includes(field), field);
  }
});

Deno.test('route page read model excludes interactive route-search results', async () => {
  const sql = normalize(
    await readSource('functions/pseo/route/build_route_page_payload.sql'),
  );

  assert.equal(sql.includes("'options', public.rpc_search_routes"), false);
  assert.ok(sql.includes("'summary', ("));
  assert.ok(sql.includes('public.route_search_options'));
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

Deno.test('route search exposes a route guide link only for the current published read model', async () => {
  const sql = normalize(await readSource('functions/route_discovery/rpc_search_routes.sql'));

  assert.ok(sql.includes('from public.route_page_read_models route_page'));
  assert.ok(sql.includes('route_page.publication_version_id = v_version_id'));
  assert.ok(
    sql.includes("route_page.canonical_slug = regexp_replace(page.route_path, '^/flights/', '')"),
  );
  assert.ok(sql.includes('then page.route_path else null end'));
});
