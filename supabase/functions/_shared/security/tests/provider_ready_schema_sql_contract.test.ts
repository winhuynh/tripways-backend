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
  ['schema/flight_routing/metro_areas.sql', 'public.metro_areas'],
  ['schema/flight_routing/metro_area_airports.sql', 'public.metro_area_airports'],
  ['schema/flight_routing/place_aliases.sql', 'public.place_aliases'],
  ['schema/flight_routing/nearby_airports.sql', 'public.nearby_airports'],
  ['schema/flight_routing/airport_terminals.sql', 'public.airport_terminals'],
  ['schema/flight_routing/airport_terminal_airlines.sql', 'public.airport_terminal_airlines'],
  ['schema/pseo/city/city_facts.sql', 'public.city_facts'],
  ['schema/pseo/airport/airport_facilities.sql', 'public.airport_facilities'],
  ['schema/pseo/airport/airport_facts.sql', 'public.airport_facts'],
  ['schema/pseo/shared/route_price_estimates.sql', 'public.route_price_estimates'],
  ['schema/pseo/route/route_pages.sql', 'public.route_pages'],
  ['schema/pseo/route/route_page_faqs.sql', 'public.route_page_faqs'],
  [
    'schema/pseo/route/route_page_airport_comparisons.sql',
    'public.route_page_airport_comparisons',
  ],
  ['schema/pseo/route/route_page_travel_facts.sql', 'public.route_page_travel_facts'],
  ['schema/pseo/route/route_page_editorial_sections.sql', 'public.route_page_editorial_sections'],
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

Deno.test('route price estimates are provider-ready but distinct from live offers', async () => {
  const sql = await read('schema/pseo/shared/route_price_estimates.sql');
  for (
    const field of [
      'trip_type',
      'cabin',
      'stop_bucket',
      'price_min',
      'price_max',
      'currency_code',
      'estimate_method',
      'sample_window_start',
      'sample_window_end',
      'sample_count',
      'source_id',
      'source_record_id',
      'confidence_score',
      'last_verified_at',
      'valid_until',
      'data_version',
    ]
  ) {
    assert.ok(sql.includes(field), `route_price_estimates must define ${field}`);
  }
  assert.equal(sql.includes('offer_id'), false);
  assert.equal(sql.includes('booking_url'), false);
});

Deno.test('structured facts require locale, citation, review, and freshness', async () => {
  for (
    const path of [
      'schema/pseo/city/city_facts.sql',
      'schema/pseo/airport/airport_facts.sql',
      'schema/pseo/airport/airport_facilities.sql',
    ]
  ) {
    const sql = await read(path);
    for (
      const field of ['locale', 'primary_source_url', 'last_verified_at', 'status', 'data_version']
    ) {
      assert.ok(sql.includes(field), `${path} must define ${field}`);
    }
  }
});
