import assert from 'node:assert/strict';
import { parseAffiliateHandoffRequest } from '../request.ts';

Deno.test('affiliate handoff accepts only one opaque observation reference', () => {
  assert.equal(
    parseAffiliateHandoffRequest({ observationRef: 'obs_0123456789abcdef0123456789abcdef' }),
    'obs_0123456789abcdef0123456789abcdef',
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
    () => parseAffiliateHandoffRequest({ observationId: crypto.randomUUID() }),
    /ERR_INVALID_REQUEST/,
  );
});
