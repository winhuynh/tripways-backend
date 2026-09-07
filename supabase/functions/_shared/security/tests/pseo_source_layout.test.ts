import assert from 'node:assert/strict';

const SQL_SOURCE_ROOT = new URL('../../../../sql_src/', import.meta.url);
const OWNERS_BY_LAYER = {
  schema: ['shared', 'city', 'airport', 'route'],
  functions: ['shared', 'homepage', 'city', 'airport', 'route'],
} as const;

for (const layer of ['schema', 'functions'] as const) {
  Deno.test(`pSEO ${layer} sources are grouped by page ownership`, async () => {
    const root = new URL(`${layer}/pseo/`, SQL_SOURCE_ROOT);
    const entries = [];
    for await (const entry of Deno.readDir(root)) entries.push(entry);

    assert.deepEqual(
      entries.filter((entry) => entry.isDirectory).map((entry) => entry.name).sort(),
      OWNERS_BY_LAYER[layer].toSorted(),
    );
    assert.equal(entries.filter((entry) => entry.isFile && entry.name.endsWith('.sql')).length, 0);
  });
}
