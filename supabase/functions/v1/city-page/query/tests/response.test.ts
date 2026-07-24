import assert from 'node:assert/strict';
import { mapCityPageResponse } from '../response.ts';

Deno.test('city page response maps the internal RPC envelope', () => {
  assert.deepEqual(
    mapCityPageResponse({ data: { city: 'Bangkok' }, meta: { data_version: 'v1' }, error: null }),
    {
      status: 'success',
      data: { city: 'Bangkok' },
      meta: { data_version: 'v1' },
      error: null,
    },
  );
});

Deno.test('city page response rejects failed and malformed envelopes', () => {
  assert.throws(
    () => mapCityPageResponse({ data: null, meta: {}, error: { code: 'ERR' } }),
    /ERR_CITY_PAGE_CONTRACT/,
  );
  assert.throws(() => mapCityPageResponse({ data: [] }), /ERR_CITY_PAGE_CONTRACT/);
});
