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
  ['schema/ingestion/raw_import_batches.sql', 'admin.raw_import_batches'],
  ['schema/ingestion/raw_base_data_records.sql', 'admin.raw_base_data_records'],
  ['schema/ingestion/ourairports_denylist.sql', 'admin.ourairports_denylist'],
] as const;

Deno.test('ingestion stores one admin table per source file', async () => {
  for (const [path, qualifiedTable] of expectedTables) {
    const sql = await readSource(path);
    assert.ok(
      includesSql(sql, `create table ${qualifiedTable}`),
      `${path} must define ${qualifiedTable}`,
    );
    assert.equal((sql.match(/create table /gi) ?? []).length, 1);
  }
});

Deno.test('raw batches enforce source checksum idempotency and bounded status', async () => {
  const sql = await readSource('schema/ingestion/raw_import_batches.sql');

  assert.ok(includesSql(sql, 'unique (source_id, checksum)'));
  assert.ok(includesSql(sql, 'idempotency_key text not null'));
  assert.ok(sql.includes('source_url'));
  assert.ok(sql.includes('filter_version'));
  assert.ok(sql.includes('raw_record_count'));
  assert.ok(sql.includes('eligible_record_count'));
  assert.ok(sql.includes('filtered_record_count'));
  assert.ok(includesSql(sql, "'awaiting_review'"));
  assert.ok(includesSql(sql, "'unchanged'"));
  assert.ok(
    includesSql(
      sql,
      'revoke all on table admin.raw_import_batches from public, anon, authenticated',
    ),
  );
});

Deno.test('raw records preserve payload privately and constrain validation state', async () => {
  const sql = await readSource('schema/ingestion/raw_base_data_records.sql');

  assert.ok(includesSql(sql, 'payload jsonb not null'));
  for (
    const recordType of [
      'country',
      'city',
      'place_alias',
      'metro_area',
      'airport',
      'airport_terminal',
      'airline',
      'flight_route',
      'flight_service',
      'route_price_estimate',
      'city_fact',
      'airport_facility',
      'airport_fact',
      'page_editorial_content',
    ]
  ) {
    assert.ok(sql.includes(`'${recordType}'`), `raw records must accept ${recordType}`);
  }
  assert.ok(includesSql(sql, "validation_state in ('pending', 'valid', 'invalid')"));
  assert.ok(
    includesSql(
      sql,
      'revoke all on table admin.raw_base_data_records from public, anon, authenticated',
    ),
  );
});

Deno.test('provider registry remains in admin and redundant log tables are removed', async () => {
  const sql = await readSource('schema/flight_routing/data_sources.sql');

  for (
    const field of [
      'code',
      'name',
      'created_at',
      'updated_at',
    ]
  ) {
    assert.ok(sql.includes(field), `data_sources must define ${field}`);
  }
  assert.ok(includesSql(sql, 'code text not null unique'));
  assert.equal(await readSource('schema/ingestion/ingestion_runs.sql'), '');
  assert.equal(await readSource('schema/ingestion/ingestion_issues.sql'), '');
});

Deno.test('ingestion operational tables grant access only to service role', async () => {
  for (const [path, qualifiedTable] of expectedTables) {
    const sql = await readSource(path);
    assert.ok(
      includesSql(
        sql,
        `grant select, insert, update, delete on table ${qualifiedTable} to service_role`,
      ),
    );
    assert.equal(includesSql(sql, ' to anon'), false);
    assert.equal(includesSql(sql, ' to authenticated'), false);
  }
});

Deno.test('publication is internal, atomic, idempotent, and unknown-safe', async () => {
  const sql = await readSource('functions/ingestion/publish_base_data_batch.sql');

  assert.ok(includesSql(sql, 'create or replace function admin.publish_base_data_batch'));
  assert.ok(includesSql(sql, 'security definer'));
  assert.ok(includesSql(sql, "set search_path = ''"));
  assert.ok(includesSql(sql, 'err_ingestion_batch_duplicate'));
  assert.ok(includesSql(sql, 'err_ingestion_validation_failed'));
  assert.ok(includesSql(sql, 'insert into public.countries'));
  assert.ok(includesSql(sql, 'insert into public.cities'));
  assert.ok(includesSql(sql, 'insert into public.airports'));
  assert.ok(includesSql(sql, 'on conflict (iso2) do nothing'));
  assert.ok(includesSql(sql, 'on conflict (country_id, slug) do nothing'));
  assert.ok(includesSql(sql, "record.record_type = 'city'"));
  assert.ok(includesSql(sql, 'err_ingestion_anomaly_review_required'));
  assert.ok(includesSql(sql, "status = 'inactive'"));
  assert.ok(includesSql(sql, "status = 'active'"));
  assert.ok(includesSql(sql, 'pg_advisory_xact_lock'));
  assert.equal(includesSql(sql, 'public.publish_read_model_version'), false);
  assert.ok(includesSql(sql, "batch.received_at < now() - interval '30 days'"));
  assert.ok(includesSql(sql, 'revoke all on function admin.publish_base_data_batch'));
  assert.ok(includesSql(sql, 'grant execute on function admin.publish_base_data_batch'));
});

Deno.test('OurAirports denylist is internal and readable only through a service-role RPC', async () => {
  const tableSql = await readSource('schema/ingestion/ourairports_denylist.sql');
  const rpcSql = await readSource('functions/ingestion/rpc_get_ourairports_denylist.sql');

  assert.ok(includesSql(tableSql, 'create table admin.ourairports_denylist'));
  assert.ok(includesSql(tableSql, "iata ~ '^[A-Z]{3}$'"));
  assert.ok(includesSql(tableSql, 'revoke all on table admin.ourairports_denylist'));
  assert.ok(includesSql(rpcSql, 'create or replace function public.rpc_get_ourairports_denylist'));
  assert.ok(includesSql(rpcSql, 'to service_role'));
  assert.equal(includesSql(rpcSql, 'to anon'), false);
  assert.equal(includesSql(rpcSql, 'to authenticated'), false);
});

Deno.test('one cron installer schedules base data ingestion', async () => {
  const sql = await readSource('operations/configure_ingestion_crons.sql');

  assert.ok(includesSql(sql, 'create extension if not exists pg_cron'));
  assert.ok(includesSql(sql, 'create extension if not exists pg_net'));
  assert.ok(includesSql(sql, 'cron.schedule('));
  assert.ok(sql.includes("'tripways-ourairports-daily'"));
  assert.ok(sql.includes("'0 2 * * *'"));
  assert.ok(sql.includes("'/functions/v1/ingestion-base-data'"));
  assert.ok(sql.includes('vault.decrypted_secrets'));
  assert.ok(sql.includes("'ourairports'"));
  assert.ok(includesSql(sql, 'err_cron_vault_prerequisites_missing'));
});

Deno.test('OurAirports source fixture records lean source configuration', async () => {
  const sql = await Deno.readTextFile(
    new URL('../../../../seed/ourairports_source.sql', import.meta.url),
  );

  assert.ok(sql.includes("'ourairports'"));
  assert.ok(sql.includes("'OurAirports'"));
  assert.doesNotMatch(sql, /openflights/i);
});

Deno.test('Travelpayouts source is configured cleanly', async () => {
  const sql = await Deno.readTextFile(
    new URL('../../../../seed/travelpayouts_source.sql', import.meta.url),
  );
  assert.ok(sql.includes("'travelpayouts'"));
  assert.ok(sql.includes('Travelpayouts'));
});

Deno.test('direct flight routes ingestion functions enforce service_role and transaction safety', async () => {
  const batchSql = await readSource('functions/ingestion/ingest_direct_flight_routes_batch.sql');
  assert.ok(
    includesSql(batchSql, 'create or replace function admin.ingest_direct_flight_routes_batch'),
  );
  assert.ok(includesSql(batchSql, 'insert into public.direct_flight_routes'));
  assert.ok(includesSql(batchSql, 'on conflict (source_id, source_record_id) do update'));
  assert.ok(
    includesSql(
      batchSql,
      'grant execute on function admin.ingest_direct_flight_routes_batch(text, jsonb) to service_role',
    ),
  );

  const rpcSql = await readSource('functions/ingestion/rpc_ingest_direct_flight_routes.sql');
  assert.ok(
    includesSql(rpcSql, 'create or replace function public.rpc_ingest_direct_flight_routes'),
  );
  assert.ok(includesSql(rpcSql, 'admin.ingest_direct_flight_routes_batch'));
  assert.ok(
    includesSql(
      rpcSql,
      'grant execute on function public.rpc_ingest_direct_flight_routes(text, jsonb) to service_role',
    ),
  );
});
