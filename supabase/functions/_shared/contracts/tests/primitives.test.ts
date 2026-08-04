import assert from 'node:assert/strict';
import {
  parseBoundedInteger,
  parseCode,
  parseCodeList,
  parseLocale,
  parseNonNegativeNumber,
  parseSlug,
} from '../primitives.ts';

Deno.test('shared primitives normalize common page boundary values', () => {
  assert.equal(parseSlug(' Bangkok '), 'bangkok');
  assert.equal(parseLocale(undefined), 'en-GB');
  assert.equal(parseCode(' sgn ', 3), 'SGN');
  assert.deepEqual(parseCodeList(['sq', 'SQ'], 2), ['SQ']);
  assert.equal(parseBoundedInteger(3, 0, 3), 3);
  assert.equal(parseNonNegativeNumber(0), 0);
});

Deno.test('shared primitives fail closed with the caller error code', () => {
  assert.throws(() => parseSlug('Bangkok!'), /ERR_SHARED_INVALID/);
  assert.throws(() => parseLocale('en_gb'), /ERR_SHARED_INVALID/);
  assert.throws(() => parseCode('SG', 3), /ERR_SHARED_INVALID/);
  assert.throws(() => parseBoundedInteger(4, 0, 3), /ERR_SHARED_INVALID/);
  assert.throws(() => parseNonNegativeNumber(-1), /ERR_SHARED_INVALID/);
});
