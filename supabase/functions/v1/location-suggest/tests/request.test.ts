import * as assert from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { parseLocationSuggestRequest } from '../request.ts';

Deno.test('parseLocationSuggestRequest accepts valid parameters', () => {
  const result = parseLocationSuggestRequest({
    query: '  Da Nang  ',
    origin_iata: 'dad',
    radius_km: 300,
    limit: 10,
  });

  assert.assertEquals(result, {
    query: 'Da Nang',
    origin_iata: 'DAD',
    radius_km: 300,
    limit: 10,
  });
});

Deno.test('parseLocationSuggestRequest rejects invalid IATA', () => {
  assert.assertThrows(
    () =>
      parseLocationSuggestRequest({
        origin_iata: 'INVALID_IATA',
      }),
    Error,
    'ERR_LOCATION_SUGGEST_INVALID_REQUEST',
  );
});

Deno.test('parseLocationSuggestRequest rejects non-record payload', () => {
  assert.assertThrows(
    () => parseLocationSuggestRequest('invalid'),
    Error,
    'ERR_LOCATION_SUGGEST_INVALID_REQUEST',
  );
});
