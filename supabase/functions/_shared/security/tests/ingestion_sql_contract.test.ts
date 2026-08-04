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
  ['schema/ingestion/raw_import_batches.sql', 'private.raw_import_batches'],
  ['schema/ingestion/raw_base_data_records.sql', 'private.raw_base_data_records'],
  ['schema/ingestion/ingestion_runs.sql', 'admin.ingestion_runs'],
  ['schema/ingestion/ingestion_issues.sql', 'admin.ingestion_issues'],
] as const;

Deno.test('ingestion stores one private or admin table per source file', async () => {
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
  assert.ok(includesSql(sql, "status in ('received', 'validated', 'published', 'rejected')"));
  assert.ok(
    includesSql(
      sql,
      'revoke all on table private.raw_import_batches from public, anon, authenticated',
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
      'revoke all on table private.raw_base_data_records from public, anon, authenticated',
    ),
  );
});

Deno.test('data sources encode provider switching and complete publication rights', async () => {
  const sql = await readSource('schema/flight_routing/data_sources.sql');

  for (
    const field of [
      'provider_code',
      'storage_allowed',
      'retention_days',
      'production_display_allowed',
      'cache_allowed',
      'max_cache_ttl_seconds',
      'attribution_text',
      'attribution_url',
      'rights_effective_at',
      'rights_expires_at',
    ]
  ) {
    assert.ok(sql.includes(field), `data_sources must define ${field}`);
  }
  assert.ok(includesSql(sql, 'unique (provider_code, code)'));
  assert.ok(includesSql(sql, 'rights_effective_at < rights_expires_at'));
});

Deno.test('ingestion runs are explicitly atomic and expose stable result counts', async () => {
  const sql = await readSource('schema/ingestion/ingestion_runs.sql');

  assert.ok(includesSql(sql, "mode text not null default 'atomic'"));
  assert.ok(includesSql(sql, "check (mode = 'atomic')"));
  assert.ok(includesSql(sql, 'accepted_count integer not null default 0'));
  assert.ok(includesSql(sql, 'rejected_count integer not null default 0'));
  assert.ok(includesSql(sql, 'stable_error_code text null'));
});

Deno.test('ingestion issues store bounded identity and severity without raw payload', async () => {
  const sql = await readSource('schema/ingestion/ingestion_issues.sql');

  assert.ok(includesSql(sql, 'source_key_hash text null'));
  assert.ok(includesSql(sql, 'issue_code text not null'));
  assert.ok(includesSql(sql, "severity in ('warning', 'error')"));
  assert.equal(includesSql(sql, 'payload jsonb'), false);
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

Deno.test('publication is private, atomic, idempotent, and unknown-safe', async () => {
  const sql = await readSource('functions/ingestion/publish_base_data_batch.sql');

  assert.ok(includesSql(sql, 'create or replace function private.publish_base_data_batch'));
  assert.ok(includesSql(sql, 'security definer'));
  assert.ok(includesSql(sql, "set search_path = ''"));
  assert.ok(includesSql(sql, 'err_ingestion_batch_duplicate'));
  assert.ok(includesSql(sql, 'err_ingestion_validation_failed'));
  assert.ok(includesSql(sql, 'insert into public.countries'));
  assert.ok(includesSql(sql, 'insert into public.cities'));
  assert.ok(includesSql(sql, 'insert into public.airports'));
  assert.ok(includesSql(sql, 'revoke all on function private.publish_base_data_batch'));
  assert.ok(includesSql(sql, 'grant execute on function private.publish_base_data_batch'));
});
