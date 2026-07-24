import assert from 'node:assert/strict';
import { mapRouteSearchResponse } from '../response.ts';

const route = {
  id: 'route-1',
  from: 'SGN',
  to: 'SIN',
  stops: 0,
  connection_airports: [],
  operating_airlines: ['SQ'],
  total_flight_minutes: 125,
  layover_minutes: null,
  total_duration_minutes: 125,
  departure_local_time: '09:00',
  arrival_local_time: '12:05',
  arrival_day_offset: 0,
  valid_from: '2026-01-01',
  valid_to: '2026-12-31',
  days_of_week: [1, 3, 5],
  confidence_score: 0.95,
  data_version: 'fixture-v1',
};

Deno.test('route response maps the internal RPC envelope to the public contract', () => {
  assert.deepEqual(
    mapRouteSearchResponse({
      data: [route],
      meta: {
        total: 1,
        limit: 20,
        offset: 0,
        facets: {
          stops: [{ value: 0, count: 1 }],
          airlines: [{ value: 'SQ', count: 1 }],
        },
      },
      error: null,
    }),
    {
      status: 'success',
      data: {
        routes: [route],
        pagination: { total: 1, limit: 20, offset: 0 },
        facets: {
          stops: [{ value: 0, count: 1 }],
          airlines: [{ value: 'SQ', count: 1 }],
        },
      },
      error: null,
    },
  );
});

Deno.test('route response rejects malformed or failed internal envelopes', () => {
  for (
    const value of [
      null,
      { data: 'invalid', meta: {}, error: null },
      { data: [{}], meta: { total: 1, limit: 20, offset: 0, facets: {} }, error: null },
      { data: [], meta: { total: 0 }, error: null },
      { data: [], meta: {}, error: { code: 'ERR_INVALID_REQUEST' } },
    ]
  ) {
    assert.throws(() => mapRouteSearchResponse(value), /ERR_ROUTE_DISCOVERY_CONTRACT/);
  }
});
