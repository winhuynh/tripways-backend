import assert from 'node:assert/strict';
import { parseRouteSearchRequest } from '@shared/contracts/route-filters.ts';
import { toRouteSearchRpcInput } from '../rpc-input.ts';

Deno.test('route search transport maps canonical camelCase contract once', () => {
  const request = parseRouteSearchRequest({
    scope: { type: 'origin_city', key: 'bangkok' },
    filters: {
      price_max: 900,
      currency: 'USD',
    },
    page_size: 20,
    after: null,
  });
  const result = toRouteSearchRpcInput(request);
  assert.equal(result.scope.type, 'origin_city');
  if (result.scope.type === 'origin_city') {
    assert.equal(result.scope.key, 'bangkok');
  }
  assert.equal(result.filters.currency, 'USD');
  assert.equal((result.filters as unknown as Record<string, unknown>).max_amount, 900);
  assert.equal(result.page_size, 20);
});
