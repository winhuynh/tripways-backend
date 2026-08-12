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

Deno.test('all page builders compose aggregate content and the lean route projection', async () => {
  for (const type of ['city', 'airport', 'route']) {
    const sql = await read(`functions/pseo/${type}/build_${type}_page_payload.sql`);
    assert.ok(sql.includes('.content'));
    assert.ok(sql.includes('public.flight_route_options'));
    assert.equal(sql.includes('public.route_search_options'), false);
  }
});

Deno.test('route page adds only fresh content observations', async () => {
  const sql = await read('functions/pseo/route/build_route_page_payload.sql');
  assert.ok(sql.includes('public.flight_content_observations'));
  assert.ok(sql.includes("item.status='published'"));
  assert.ok(sql.includes('item.valid_until>now()'));
  assert.ok(sql.includes('item.observed_amount'));
});

Deno.test('publication refreshes one shared lean projection before all page read models', async () => {
  const publish = await read('functions/pseo/shared/publish_read_model_version.sql');
  const refresh = await read('functions/pseo/shared/refresh_page_read_models.sql');
  assert.ok(publish.includes('private.refresh_route_search_options(v_version_id)'));
  assert.ok(publish.includes('private.refresh_page_read_models(v_version_id)'));
  assert.ok(refresh.includes('public.city_page_read_models'));
  assert.ok(refresh.includes('public.airport_page_read_models'));
  assert.ok(refresh.includes('public.route_page_read_models'));
});

Deno.test('homepage reads only the current flight route projection', async () => {
  for (
    const file of [
      'rpc_search_places.sql',
      'rpc_resolve_homepage_origin.sql',
      'rpc_get_homepage_statistics.sql',
    ]
  ) {
    const sql = await read(`functions/pseo/homepage/${file}`);
    assert.ok(sql.includes('public.flight_route_options'), file);
    assert.ok(sql.includes('public.publication_versions'), file);
    assert.equal(sql.includes('public.route_search_options'), false);
  }
});

Deno.test('public route search is read-only and service-role only', async () => {
  const sql = await read('functions/route_discovery/rpc_search_routes.sql');
  assert.ok(sql.includes('public.flight_route_options'));
  assert.ok(sql.includes('stable'));
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
