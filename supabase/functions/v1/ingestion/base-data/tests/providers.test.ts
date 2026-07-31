import assert from 'node:assert/strict';
import { loadApprovedApiProvider } from '../providers/approved-api-provider.ts';
import { loadFixtureProvider } from '../providers/fixture-provider.ts';

Deno.test('fixture provider loads deterministic offline canonical data', async () => {
  const first = await loadFixtureProvider();
  const second = await loadFixtureProvider();

  assert.deepEqual(first, second);
  assert.equal(first.ok, true);
});

Deno.test('approved API provider uses configured URL and enforces record limit', async () => {
  let requestedUrl = '';
  const fetcher: typeof fetch = (input) => {
    requestedUrl = String(input);
    return Promise.resolve(
      new Response(
        JSON.stringify({
          schemaVersion: 'base-data.v1',
          sourceTime: null,
          countries: [
            { iso2: 'SG', iso3: 'SGP', name: 'Singapore' },
            { iso2: 'TH', iso3: 'THA', name: 'Thailand' },
          ],
          cities: [],
          airports: [],
        }),
        { status: 200 },
      ),
    );
  };

  const result = await loadApprovedApiProvider({
    baseUrl: 'https://approved.example.test/base-data',
    maxRecords: 1,
    fetcher,
  });

  assert.equal(requestedUrl, 'https://approved.example.test/base-data?limit=1');
  assert.equal(result.ok, false);
  if (result.ok) return;
  assert.equal(result.issues[0]?.code, 'ERR_PROVIDER_RECORD_LIMIT');
});

Deno.test('approved API provider rejects non-HTTPS configuration before fetching', async () => {
  let called = false;
  const result = await loadApprovedApiProvider({
    baseUrl: 'http://unapproved.example.test/base-data',
    maxRecords: 5,
    fetcher: () => {
      called = true;
      return Promise.resolve(new Response('{}'));
    },
  });

  assert.equal(called, false);
  assert.equal(result.ok, false);
});
