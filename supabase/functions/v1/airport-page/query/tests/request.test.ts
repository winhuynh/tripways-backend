import assert from 'node:assert/strict';
import { parseAirportPageQueryRequest } from '../request.ts';

Deno.test('airport page request bounds identity and route filters', () => {
  assert.deepEqual(
    parseAirportPageQueryRequest({
      action: 'search_routes',
      input: {
        airport_iata: 'bkk',
        locale: 'en-GB',
        direction: 'outbound',
        airlines: ['sq'],
        countries: ['sg'],
        max_duration_minutes: 360,
        limit: 24,
        offset: 0,
      },
    }),
    {
      action: 'search_routes',
      input: {
        airport_iata: 'BKK',
        locale: 'en-GB',
        direction: 'outbound',
        airlines: ['SQ'],
        countries: ['SG'],
        max_duration_minutes: 360,
        limit: 24,
        offset: 0,
      },
    },
  );
});

Deno.test('airport page request rejects unknown actions and fields', () => {
  assert.throws(
    () => parseAirportPageQueryRequest({ action: 'raw_sql', input: { query: 'select 1' } }),
    /ERR_AIRPORT_PAGE_INVALID_REQUEST/,
  );
});
