import assert from 'node:assert/strict';
import { parseCityPageQueryRequest } from '../request.ts';

Deno.test('city page request normalizes identity and destination filters', () => {
  assert.deepEqual(
    parseCityPageQueryRequest({
      action: 'get_destinations',
      input: {
        city_slug: ' Bangkok ',
        origin_airports: [' dmk ', 'DMK'],
        airlines: ['tg'],
        limit: 8,
      },
    }),
    {
      action: 'get_destinations',
      input: {
        city_slug: 'bangkok',
        locale: 'en-GB',
        origin_airports: ['DMK'],
        airlines: ['TG'],
        limit: 8,
      },
    },
  );
});

Deno.test('city page request rejects unsupported actions and cross-action fields', () => {
  assert.throws(
    () => parseCityPageQueryRequest({ action: 'unknown', input: { city_slug: 'bangkok' } }),
    /ERR_CITY_PAGE_INVALID_REQUEST/,
  );
  assert.throws(
    () =>
      parseCityPageQueryRequest({
        action: 'get_overview',
        input: { city_slug: 'bangkok', limit: 8 },
      }),
    /ERR_CITY_PAGE_INVALID_REQUEST/,
  );
});
