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

const tables = [
  ['schema/flight_routing/flight_route_prices.sql', 'public.flight_route_prices'],
  ['schema/pseo/route/route_pages.sql', 'public.route_pages'],
] as const;

Deno.test('provider-ready canonical tables are isolated, protected, and versionable', async () => {
  for (const [path, table] of tables) {
    const sql = await read(path);
    assert.ok(sql.includes(`create table ${table}`), `${path} must create ${table}`);
    assert.equal((sql.match(/create table /g) ?? []).length, 1);
    assert.ok(sql.includes(`alter table ${table} enable row level security`));
    assert.ok(sql.includes(`revoke all on table ${table} from anon, authenticated`));
    assert.ok(
      sql.includes(`grant select, insert, update, delete on table ${table} to service_role`),
    );
  }
});

Deno.test('flight route prices are short-lived and distinct from live offers', async () => {
  const sql = await read('schema/flight_routing/flight_route_prices.sql');
  for (
    const field of [
      'trip_type',
      'observation_type',
      'direct',
      'transfer_count',
      'observed_amount',
      'provider_airline_iata',
      'canonical_airline_id',
      'currency_code',
      'market_code',
      'locale',
      'departure_date',
      'return_date',
      'duration_minutes',
      'data_source',
      'provider_code',
      'source_record_id',
      'observed_at',
      'provider_expires_at',
      'valid_until',
      'affiliate_path',
      'public_reference',
      'data_version',
    ]
  ) {
    assert.ok(sql.includes(field), `flight route prices must define ${field}`);
  }
  assert.equal(sql.includes('price_min'), false);
  assert.equal(sql.includes('price_max'), false);
  assert.equal(sql.includes('offer_id'), false);
  assert.equal(sql.includes('booking_url'), false);
});

Deno.test('affiliate handoff uses a fixed partner host and rejects expired observations', async () => {
  const sql = await read('functions/pseo/shared/rpc_get_flight_affiliate_handoff.sql');
  const compact = sql.replaceAll(/\s+/g, '');
  assert.ok(sql.includes('p_observation_ref text'));
  assert.ok(compact.includes('observation.public_reference=input.requested_reference'));
  assert.ok(sql.includes("'https://www.aviasales.com'"));
  assert.ok(compact.includes('observation.valid_until>now()'));
  assert.ok(compact.includes("observation.provider_code='travelpayouts'"));
  assert.equal(sql.includes('p_url'), false);
});

Deno.test('route payload exposes a public observation reference without internal IDs', async () => {
  const sql = await read('functions/pseo/route/build_route_page_payload.sql');
  for (
    const field of [
      'observation_ref',
      'public_reference',
      'observed_amount',
      'currency_code',
      'departure_date',
      'observed_at',
      'valid_until',
    ]
  ) assert.ok(sql.includes(field));
  assert.equal(sql.includes("'observation_id'"), false);
  assert.equal(sql.includes("'id',"), false);
  assert.equal(sql.includes("'affiliate_path'"), false);
});

Deno.test('legacy route observation resolver is removed', async () => {
  assert.equal(await read('functions/pseo/shared/resolve_route_price_estimate.sql'), '');
});

Deno.test('page sources use one aggregate while read models remain separate', async () => {
  for (const type of ['city', 'airport', 'route']) {
    const page = await read(`schema/pseo/${type}/${type}_pages.sql`);
    const model = await read(`schema/pseo/${type}/${type}_page_read_models.sql`);
    assert.ok(page.includes('content jsonb not null'));
    assert.ok(model.includes(`create table public.${type}_page_read_models`));
  }
});
