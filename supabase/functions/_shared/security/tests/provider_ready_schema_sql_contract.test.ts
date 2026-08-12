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
  ['schema/flight_routing/place_aliases.sql', 'public.place_aliases'],
  ['schema/flight_routing/flight_content_observations.sql', 'public.flight_content_observations'],
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

Deno.test('flight content observations are short-lived and distinct from live offers', async () => {
  const sql = await read('schema/flight_routing/flight_content_observations.sql');
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
      'source_id',
      'source_record_id',
      'observed_at',
      'provider_expires_at',
      'valid_until',
      'affiliate_path',
      'data_version',
    ]
  ) {
    assert.ok(sql.includes(field), `flight content observations must define ${field}`);
  }
  assert.equal(sql.includes('price_min'), false);
  assert.equal(sql.includes('price_max'), false);
  assert.equal(sql.includes('offer_id'), false);
  assert.equal(sql.includes('booking_url'), false);
});

Deno.test('affiliate handoff uses a fixed partner host and rejects expired observations', async () => {
  const sql = await read('functions/pseo/shared/rpc_get_flight_affiliate_handoff.sql');
  assert.ok(sql.includes("'https://www.aviasales.com'"));
  assert.ok(sql.includes('observation.valid_until>now()'));
  assert.ok(sql.includes("source.provider_code='travelpayouts'"));
  assert.equal(sql.includes('p_url'), false);
});

Deno.test('route observation resolver does not query removed estimate dimensions', async () => {
  const sql = await read('functions/pseo/shared/resolve_route_price_estimate.sql');
  assert.equal(sql.includes('estimate.cabin'), false);
  assert.equal(sql.includes('estimate.stop_bucket'), false);
  assert.ok(sql.includes('estimate.observed_at'));
});

Deno.test('page sources use one aggregate while read models remain separate', async () => {
  for (const type of ['city', 'airport', 'route']) {
    const page = await read(`schema/pseo/${type}/${type}_pages.sql`);
    const model = await read(`schema/pseo/${type}/${type}_page_read_models.sql`);
    assert.ok(page.includes('content jsonb not null'));
    assert.ok(model.includes(`create table public.${type}_page_read_models`));
  }
});
