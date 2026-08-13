import assert from 'node:assert/strict';

const sourceRoot = new URL('../../../../sql_src/', import.meta.url);

async function collectSqlFiles(root: URL): Promise<URL[]> {
  const files: URL[] = [];
  for await (const entry of Deno.readDir(root)) {
    const child = new URL(entry.name + (entry.isDirectory ? '/' : ''), root);
    if (entry.isDirectory) files.push(...await collectSqlFiles(child));
    else if (entry.name.endsWith('.sql')) files.push(child);
  }
  return files;
}

async function read(relativePath: string): Promise<string> {
  try {
    return (await Deno.readTextFile(new URL(relativePath, sourceRoot))).toLowerCase();
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return '';
    throw error;
  }
}

Deno.test('each SQL function source defines exactly one function', async () => {
  const files = await collectSqlFiles(new URL('functions/', sourceRoot));
  for (const file of files) {
    const sql = await Deno.readTextFile(file);
    assert.equal(
      (sql.match(/^CREATE OR REPLACE FUNCTION /gm) ?? []).length,
      1,
      file.pathname,
    );
  }
});

Deno.test('public SQL functions never use security definer', async () => {
  const files = await collectSqlFiles(new URL('functions/', sourceRoot));
  for (const file of files) {
    const sql = (await Deno.readTextFile(file)).toLowerCase();
    if (sql.includes('create or replace function public.')) {
      assert.equal(sql.includes('security definer'), false, file.pathname);
    }
  }
});

Deno.test('unused schema and helper sources stay removed', async () => {
  for (
    const path of [
      'schema/flight_routing/place_aliases.sql',
      'schema/pseo/shared/pseo_internal_links.sql',
      'functions/_shared/normalize_airport_iata.sql',
      'functions/_shared/normalize_airline_iata.sql',
    ]
  ) assert.equal(await read(path), '', path);
});

Deno.test('read-model publication avoids repeated payload builds and lifecycle updates', async () => {
  const refresh = await read('functions/pseo/shared/refresh_page_read_models.sql');
  for (const type of ['city', 'airport', 'route']) {
    assert.equal(
      (refresh.match(new RegExp(`admin\\.build_${type}_page_payload`, 'g')) ?? []).length,
      1,
      type,
    );
  }

  const publish = await read('functions/pseo/shared/publish_read_model_version.sql');
  assert.equal((publish.match(/update public\.pseo_pages/g) ?? []).length, 1);
});

Deno.test('admin schema usage is granted only by the platform schema source', async () => {
  const files = await collectSqlFiles(sourceRoot);
  const owners: string[] = [];
  for (const file of files) {
    const sql = (await Deno.readTextFile(file)).toLowerCase();
    if (sql.includes('grant usage on schema admin')) owners.push(file.pathname);
  }
  assert.equal(owners.length, 1, owners.join(', '));
  assert.ok(owners[0]?.endsWith('/schema/_platform/admin.sql'));
});
