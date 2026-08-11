import assert from 'node:assert/strict';
import { parsePageRequest } from '../page-request.ts';

Deno.test('shared page request normalizes every page identity', () => {
  assert.deepEqual(
    parsePageRequest({
      action: 'get_page',
      input: { page_type: 'city', entity_key: ' Bangkok ', locale: 'en-GB' },
    }),
    {
      action: 'get_page',
      input: { pageType: 'city', entityKey: 'bangkok', locale: 'en-GB' },
    },
  );
  assert.equal(
    parsePageRequest({ action: 'get_page', input: { page_type: 'airport', entity_key: 'bkk' } })
      .input.entityKey,
    'BKK',
  );
});

Deno.test('shared page request rejects unsupported actions and fields', () => {
  assert.throws(
    () =>
      parsePageRequest({
        action: 'get_page',
        input: { page_type: 'homepage', entity_key: 'homepage' },
      }),
    /ERR_PAGE_INVALID_REQUEST/,
  );
  assert.throws(
    () => parsePageRequest({ action: 'get_city', input: {} }),
    /ERR_PAGE_INVALID_REQUEST/,
  );
  assert.throws(
    () =>
      parsePageRequest({
        action: 'get_page',
        input: { page_type: 'city', entity_key: 'bangkok', offset: 1 },
      }),
    /ERR_PAGE_INVALID_REQUEST/,
  );
});
