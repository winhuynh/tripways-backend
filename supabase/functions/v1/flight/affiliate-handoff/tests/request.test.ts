import assert from 'node:assert/strict';
import { parseAffiliateHandoffRequest } from '../request.ts';

Deno.test('affiliate handoff accepts valid observation reference', () => {
  assert.deepEqual(
    parseAffiliateHandoffRequest({ observationRef: 'obs_0123456789abcdef0123456789abcdef' }),
    { type: 'observation', observationRef: 'obs_0123456789abcdef0123456789abcdef' },
  );

  assert.throws(
    () => parseAffiliateHandoffRequest({ observationRef: 'not-a-reference' }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () =>
      parseAffiliateHandoffRequest({
        observationRef: 'obs_0123456789abcdef0123456789abcdef',
        url: 'https://evil.example',
      }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () =>
      parseAffiliateHandoffRequest({
        observationRef: 'obs_0123456789abcdef0123456789abcdef',
        originIata: 'SFO',
      }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAffiliateHandoffRequest({ observationId: crypto.randomUUID() }),
    /ERR_INVALID_REQUEST/,
  );
});

Deno.test('affiliate handoff accepts valid fallback search requests', () => {
  assert.deepEqual(
    parseAffiliateHandoffRequest({ originIata: 'SFO', destIata: 'JFK' }),
    { type: 'fallback_search', originIata: 'SFO', destIata: 'JFK' },
  );

  assert.deepEqual(
    parseAffiliateHandoffRequest({
      originIata: 'DAD',
      destIata: 'KEF',
      departureDate: '2026-09-15',
    }),
    {
      type: 'fallback_search',
      originIata: 'DAD',
      destIata: 'KEF',
      departureDate: '2026-09-15',
    },
  );

  assert.deepEqual(
    parseAffiliateHandoffRequest({
      originIata: 'SGN',
      destIata: 'HAN',
      locale: 'en-GB',
    }),
    {
      type: 'fallback_search',
      originIata: 'SGN',
      destIata: 'HAN',
      locale: 'en-GB',
    },
  );

  assert.deepEqual(
    parseAffiliateHandoffRequest({
      originIata: 'SGN',
      destIata: 'LHR',
      departureDate: '2026-10-20',
      locale: 'vi',
    }),
    {
      type: 'fallback_search',
      originIata: 'SGN',
      destIata: 'LHR',
      departureDate: '2026-10-20',
      locale: 'vi',
    },
  );
});

Deno.test('affiliate handoff rejects invalid fallback search requests', () => {
  // Lowercase IATA
  assert.throws(
    () => parseAffiliateHandoffRequest({ originIata: 'sfo', destIata: 'JFK' }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAffiliateHandoffRequest({ originIata: 'SFO', destIata: 'jfk' }),
    /ERR_INVALID_REQUEST/,
  );

  // Invalid IATA length or characters
  assert.throws(
    () => parseAffiliateHandoffRequest({ originIata: 'SF', destIata: 'JFK' }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAffiliateHandoffRequest({ originIata: 'SFO1', destIata: 'JFK' }),
    /ERR_INVALID_REQUEST/,
  );

  // Missing fields
  assert.throws(
    () => parseAffiliateHandoffRequest({ originIata: 'SFO' }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () => parseAffiliateHandoffRequest({ destIata: 'JFK' }),
    /ERR_INVALID_REQUEST/,
  );

  // Invalid departureDate
  assert.throws(
    () =>
      parseAffiliateHandoffRequest({
        originIata: 'SFO',
        destIata: 'JFK',
        departureDate: '2026/09/15',
      }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () =>
      parseAffiliateHandoffRequest({
        originIata: 'SFO',
        destIata: 'JFK',
        departureDate: '2026-13-45',
      }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () =>
      parseAffiliateHandoffRequest({
        originIata: 'SFO',
        destIata: 'JFK',
        departureDate: '2026-02-30',
      }),
    /ERR_INVALID_REQUEST/,
  );

  // Invalid locale
  assert.throws(
    () =>
      parseAffiliateHandoffRequest({
        originIata: 'SFO',
        destIata: 'JFK',
        locale: 123,
      }),
    /ERR_INVALID_REQUEST/,
  );
  assert.throws(
    () =>
      parseAffiliateHandoffRequest({
        originIata: 'SFO',
        destIata: 'JFK',
        locale: '1',
      }),
    /ERR_INVALID_REQUEST/,
  );

  // Unexpected extra fields
  assert.throws(
    () =>
      parseAffiliateHandoffRequest({
        originIata: 'SFO',
        destIata: 'JFK',
        extraField: true,
      }),
    /ERR_INVALID_REQUEST/,
  );

  // Non-object / empty inputs
  assert.throws(() => parseAffiliateHandoffRequest(null), /ERR_INVALID_REQUEST/);
  assert.throws(() => parseAffiliateHandoffRequest(undefined), /ERR_INVALID_REQUEST/);
  assert.throws(() => parseAffiliateHandoffRequest(''), /ERR_INVALID_REQUEST/);
  assert.throws(() => parseAffiliateHandoffRequest([]), /ERR_INVALID_REQUEST/);
  assert.throws(() => parseAffiliateHandoffRequest({}), /ERR_INVALID_REQUEST/);
});
