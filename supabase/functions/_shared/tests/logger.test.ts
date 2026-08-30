import assert from 'node:assert/strict';
import {
  extractRequestId,
  logEdgeError,
  logEdgeInfo,
  logEdgeWarn,
  safeExtractError,
  sanitizeLogValue,
} from '../logger.ts';

Deno.test('extractRequestId uses x-request-id if provided', () => {
  const request = new Request('https://example.test', {
    headers: { 'x-request-id': 'req-12345' },
  });
  assert.equal(extractRequestId(request), 'req-12345');
});

Deno.test('extractRequestId generates UUID if no header present', () => {
  const request = new Request('https://example.test');
  const id = extractRequestId(request);
  assert.ok(id && id.length > 10);
});

Deno.test('sanitizeLogValue redacts sensitive keys and preserves safe data', () => {
  const input = {
    user_id: 'usr_1',
    password: 'supersecretpassword',
    authorization: 'Bearer jwt.token.here',
    apiKey: 'sb-anon-key-secret',
    token: 'oauth-token',
    publicInfo: 'valid-info',
    nested: {
      clientSecret: 'secret_123',
      city: 'Bangkok',
    },
  };

  const sanitized = sanitizeLogValue(input) as Record<string, unknown>;
  assert.equal(sanitized.user_id, 'usr_1');
  assert.equal(sanitized.password, '[redacted]');
  assert.equal(sanitized.authorization, '[redacted]');
  assert.equal(sanitized.apiKey, '[redacted]');
  assert.equal(sanitized.token, '[redacted]');
  assert.equal(sanitized.publicInfo, 'valid-info');
  assert.deepEqual(sanitized.nested, {
    clientSecret: '[redacted]',
    city: 'Bangkok',
  });
});

Deno.test('safeExtractError normalizes error codes and preserves db details', () => {
  const err = new Error('ERR_PAGE_NOT_FOUND');
  const extracted = safeExtractError(err);
  assert.equal(extracted.errorCode, 'ERR_PAGE_NOT_FOUND');
  assert.equal(extracted.errorName, 'Error');

  const customDbError = {
    message: 'violates foreign key constraint',
    code: '23503',
    details: 'Key (city_id)=(123) is not present in table cities',
    hint: 'Check referenced ID',
  };
  const extractedDb = safeExtractError(customDbError, 'ERR_INTERNAL');
  assert.equal(extractedDb.errorCode, 'ERR_INTERNAL');
  assert.equal(extractedDb.errorMessage, 'violates foreign key constraint');
  assert.deepEqual(extractedDb.dbDetails, {
    details: 'Key (city_id)=(123) is not present in table cities',
    hint: 'Check referenced ID',
  });
});

Deno.test('logEdgeInfo, logEdgeWarn, and logEdgeError execute without throwing', () => {
  assert.doesNotThrow(() => {
    logEdgeInfo('TEST_EVENT', { action: 'query', durationMs: 12 });
    logEdgeWarn('TEST_WARN', new Error('Something is slow'), { action: 'cache_read' });
    logEdgeError('TEST_ERROR', new Error('ERR_PAGE_CONTRACT'), { requestId: 'req-abc' });
  });
});
