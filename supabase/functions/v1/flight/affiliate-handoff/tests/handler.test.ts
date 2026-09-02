import assert from 'node:assert/strict';
import {
  createAffiliateHandoffHandler,
  DEFAULT_DISCLOSURE,
  isAllowlistedAviasalesUrl,
} from '../handler.ts';

Deno.test('isAllowlistedAviasalesUrl validates hosts strictly', () => {
  assert.equal(isAllowlistedAviasalesUrl('https://www.aviasales.com/search/SFO1509JFK'), true);
  assert.equal(
    isAllowlistedAviasalesUrl('https://www.aviasales.com/search/DADKEF?marker=123'),
    true,
  );

  // Insecure protocol
  assert.equal(isAllowlistedAviasalesUrl('http://www.aviasales.com/search/SFOJFK'), false);

  // Phishing / subdomain spoofing
  assert.equal(isAllowlistedAviasalesUrl('https://www.aviasales.com.evil.com/search'), false);
  assert.equal(isAllowlistedAviasalesUrl('https://evil.com/www.aviasales.com'), false);
  assert.equal(isAllowlistedAviasalesUrl('https://aviasales.com.attacker.org/'), false);

  // Malformed or dangerous protocols
  assert.equal(isAllowlistedAviasalesUrl('javascript:alert(1)'), false);
  assert.equal(isAllowlistedAviasalesUrl('not-a-url'), false);
});

Deno.test('handoff handler resolves valid observation request', async () => {
  const handler = createAffiliateHandoffHandler(() =>
    Promise.resolve({
      data: {
        url: 'https://www.aviasales.com/search/SGN-LON',
        expires_at: '2026-08-19T00:00:00Z',
        disclosure: DEFAULT_DISCLOSURE,
      },
      error: null,
    })
  );

  const response = await handler(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({ observationRef: 'obs_0123456789abcdef0123456789abcdef' }),
    }),
  );

  assert.equal(response.status, 200);
  const json = await response.json();
  assert.equal(json.data.url, 'https://www.aviasales.com/search/SGN-LON');
  assert.equal(json.data.expires_at, '2026-08-19T00:00:00Z');
  assert.equal(json.data.disclosure, DEFAULT_DISCLOSURE);
  assert.equal(json.error, null);
});

Deno.test('handoff handler rejects non-allowlisted target from observation resolver', async () => {
  const handler = createAffiliateHandoffHandler(() =>
    Promise.resolve({
      data: {
        url: 'https://evil.example.com/steal-creds',
        expires_at: '2026-08-19T00:00:00Z',
      },
      error: null,
    })
  );

  const response = await handler(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({ observationRef: 'obs_0123456789abcdef0123456789abcdef' }),
    }),
  );

  assert.equal(response.status, 404);
  const json = await response.json();
  assert.equal(json.data, null);
  assert.equal(json.error.code, 'ERR_HANDOFF_UNAVAILABLE');
});

Deno.test('handoff handler generates valid fallback search URL without date', async () => {
  const handler = createAffiliateHandoffHandler();

  const response = await handler(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({ originIata: 'DAD', destIata: 'KEF' }),
    }),
  );

  assert.equal(response.status, 200);
  const json = await response.json();
  assert.ok(json.data.url.startsWith('https://www.aviasales.com/search/DADKEF'));
  assert.ok(json.data.url.includes('marker='));
  assert.ok(json.data.url.includes('sub_id=fallback_search'));
  assert.ok(typeof json.data.expires_at === 'string');
  assert.equal(json.data.disclosure, DEFAULT_DISCLOSURE);
});

Deno.test('handoff handler generates valid fallback search URL with departure date and locale', async () => {
  const handler = createAffiliateHandoffHandler(undefined, {
    marker: 'custom_marker_123',
    subId: 'test_sub',
  });

  const response = await handler(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({
        originIata: 'SFO',
        destIata: 'JFK',
        departureDate: '2026-09-15',
        locale: 'en-GB',
      }),
    }),
  );

  assert.equal(response.status, 200);
  const json = await response.json();
  assert.equal(
    json.data.url,
    'https://www.aviasales.com/search/SFO1509JFK?marker=custom_marker_123&sub_id=test_sub&locale=en-GB',
  );
  assert.ok(typeof json.data.expires_at === 'string');
  assert.equal(json.data.disclosure, DEFAULT_DISCLOSURE);
});

Deno.test('handoff handler rejects invalid request payload', async () => {
  const handler = createAffiliateHandoffHandler();

  const response = await handler(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({ originIata: 'invalid', destIata: 'JFK' }),
    }),
  );

  assert.equal(response.status, 400);
  const json = await response.json();
  assert.equal(json.error.code, 'ERR_INVALID_REQUEST');
});

Deno.test('handoff handler rejects invalid HTTP method', async () => {
  const handler = createAffiliateHandoffHandler();

  const response = await handler(
    new Request('http://local', {
      method: 'GET',
    }),
  );

  assert.equal(response.status, 405);
  const json = await response.json();
  assert.equal(json.error.code, 'ERR_METHOD_NOT_ALLOWED');
});
