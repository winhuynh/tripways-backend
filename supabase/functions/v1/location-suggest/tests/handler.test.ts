import assert from 'node:assert/strict';
import { createLocationSuggestHandler } from '../handler.ts';

Deno.test('createLocationSuggestHandler returns data on successful query', async () => {
  const mockQuery = () =>
    Promise.resolve({
      data: [
        {
          type: 'airport',
          iata: 'DAD',
          name: 'Da Nang International Airport',
          city_name: 'Da Nang',
          country_name: 'Vietnam',
        },
      ],
      meta: { data_version: 'v1' },
      error: null,
    });

  const handler = createLocationSuggestHandler(mockQuery);
  const request = new Request('https://edge.supabase.com/location-suggest', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ query: 'DAD' }),
  });

  const response = await handler(request);
  assert.equal(response.status, 200);

  const payload = await response.json();
  assert.equal(payload.data[0].iata, 'DAD');
});

Deno.test('createLocationSuggestHandler rejects invalid input', async () => {
  const handler = createLocationSuggestHandler(() =>
    Promise.resolve({
      data: [],
      meta: { data_version: 'v1' },
      error: null,
    })
  );

  const response = await handler(
    new Request('https://edge.supabase.com/location-suggest', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ origin_iata: 'INVALID' }),
    }),
  );

  assert.equal(response.status, 400);
});
