import assert from 'node:assert/strict';

const root = new URL('../../../../sql_src/', import.meta.url);
async function read(path: string): Promise<string> {
  try {
    return (await Deno.readTextFile(new URL(path, root))).toLowerCase();
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return '';
    throw error;
  }
}

Deno.test('pSEO source pages are three aggregate documents with separate read models', async () => {
  for (const type of ['city', 'airport', 'route']) {
    const page = await read(`schema/pseo/${type}/${type}_pages.sql`);
    const model = await read(`schema/pseo/${type}/${type}_page_read_models.sql`);
    assert.ok(page.includes('content jsonb not null'));
    assert.ok(page.includes(`alter table public.${type}_pages enable row level security`));
    assert.ok(model.includes(`create table public.${type}_page_read_models`));
  }
});

Deno.test('legacy page-module schemas are removed', async () => {
  for (
    const path of [
      'schema/pseo/city/city_facts.sql',
      'schema/pseo/city/city_content_sections.sql',
      'schema/pseo/airport/airport_journey_steps.sql',
      'schema/pseo/airport/airport_facilities.sql',
      'schema/pseo/route/route_page_faqs.sql',
      'schema/pseo/route/route_page_travel_facts.sql',
    ]
  ) assert.equal(await read(path), '', path);
});

Deno.test('unused city slug mutation operation is removed', async () => {
  assert.equal(await read('operations/rename_city_slug.sql'), '');
});

Deno.test('all page builders compose aggregate content and the lean route projection', async () => {
  for (const type of ['city', 'airport', 'route']) {
    const sql = await read(`functions/pseo/${type}/build_${type}_page_payload.sql`);
    assert.ok(sql.includes('.content'));
    assert.ok(sql.includes('public.flight_route_options'));
    assert.equal(sql.includes('public.route_search_options'), false);
  }
});

Deno.test('public page builders use explicit DTO allowlists without internal identifiers', async () => {
  for (const type of ['city', 'airport']) {
    const sql = await read(`functions/pseo/${type}/build_${type}_page_payload.sql`);
    assert.equal(sql.includes('to_jsonb(option)'), false);
    assert.equal(sql.includes("'canonical_airline_id'"), false);
  }
  const cityBuilder = await read('functions/pseo/city/build_city_page_payload.sql');
  for (const field of ['canonical_path', 'is_indexable', 'noindex_reason', 'source_freshness_at']) {
    assert.ok(cityBuilder.includes(field), `page response metadata must expose ${field}`);
  }
  const rpc = await read('functions/pseo/shared/rpc_get_page.sql');
  assert.ok(rpc.includes("'meta', v_metadata || jsonb_build_object"));
  assert.ok(rpc.includes("'v_' || md5"));
  assert.equal(rpc.includes("'data_version', v_version_id"), false);
});

Deno.test('route page adds only fresh content observations', async () => {
  const sql = await read('functions/pseo/route/build_route_page_payload.sql');
  const compact = sql.replaceAll(/\s+/g, '');
  assert.ok(sql.includes('public.flight_route_prices'));
  assert.ok(compact.includes("item.status='published'"));
  assert.ok(compact.includes('item.valid_until>now()'));
  assert.ok(sql.includes('item.observed_amount'));
});

Deno.test('publication refreshes one shared lean projection before all page read models', async () => {
  const publish = await read('functions/pseo/shared/publish_read_model_version.sql');
  const refresh = await read('functions/pseo/shared/refresh_page_read_models.sql');
  assert.ok(publish.includes('admin.refresh_route_search_options(v_version_id)'));
  assert.ok(publish.includes('admin.refresh_page_read_models(v_version_id)'));
  assert.ok(refresh.includes('public.city_page_read_models'));
  assert.ok(refresh.includes('public.airport_page_read_models'));
  assert.ok(refresh.includes('public.route_page_read_models'));
});

Deno.test('homepage reads only the current flight route projection', async () => {
  const sql = await read('functions/pseo/homepage/rpc_get_homepage_statistics.sql');
  assert.ok(sql.includes('public.flight_route_options'));
  assert.ok(sql.includes('public.publication_versions'));
  assert.equal(sql.includes('public.route_search_options'), false);
  assert.equal(await read('functions/pseo/homepage/rpc_search_places.sql'), '');
  assert.equal(await read('functions/pseo/homepage/rpc_resolve_homepage_origin.sql'), '');
  assert.ok(sql.includes("'v_' || md5"));
  assert.equal(sql.includes("'data_version', version.id"), false);
});

Deno.test('public route search is read-only and service-role only', async () => {
  const sql = await read('functions/route_discovery/rpc_search_routes.sql');
  assert.ok(sql.includes('public.flight_route_options'));
  assert.ok(sql.includes('stable'));
  assert.ok(sql.includes("'v_' || md5"));
  assert.equal(sql.includes("'data_version', v_version_id"), false);
  assert.equal(sql.includes("'id', id"), false);
  assert.ok(
    sql.includes(
      'revoke all on function public.rpc_search_routes(jsonb) from public, anon, authenticated',
    ),
  );
  assert.ok(
    sql.includes('grant execute on function public.rpc_search_routes(jsonb) to service_role'),
  );
});

Deno.test('canonical registry alone owns page lifecycle and sitemap state', async () => {
  const registry = await read('schema/pseo/shared/pseo_pages.sql');
  for (
    const field of ['canonical_path', 'status', 'is_indexable', 'noindex_reason', 'data_version']
  ) assert.ok(registry.includes(field));
  for (const type of ['city', 'airport', 'route']) {
    const page = await read(`schema/pseo/${type}/${type}_pages.sql`);
    assert.equal(page.includes('is_indexable'), false);
    assert.equal(page.includes('noindex_reason'), false);
  }
});
