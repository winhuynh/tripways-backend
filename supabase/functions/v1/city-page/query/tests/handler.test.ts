import assert from 'node:assert/strict';
import { type CityPageQueryDependencies, handleCityPageQuery } from '../handler.ts';

const dependencies: CityPageQueryDependencies = {
  query: () => Promise.resolve({ data: { city: 'Bangkok' }, meta: {}, error: null }),
};

Deno.test('city page handler forwards an allow-listed action', async () => {
  let received: unknown;
  const response = await handleCityPageQuery(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({ action: 'get_overview', input: { city_slug: 'bangkok' } }),
    }),
    {
      query: (action, input) => {
        received = { action, input };
        return dependencies.query(action, input);
      },
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(received, {
    action: 'get_overview',
    input: { city_slug: 'bangkok', locale: 'en-GB' },
  });
});

Deno.test('city page handler isolates validation and availability errors', async () => {
  const invalid = await handleCityPageQuery(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({ action: 'get_overview', input: {} }),
    }),
    dependencies,
  );
  assert.equal(invalid.status, 400);

  const unavailable = await handleCityPageQuery(
    new Request('https://example.test', {
      method: 'POST',
      body: JSON.stringify({ action: 'get_faqs', input: { city_slug: 'bangkok' } }),
    }),
    { query: () => Promise.reject(new Error('ERR_CITY_PAGE_UNAVAILABLE')) },
  );
  assert.equal(unavailable.status, 503);
});
