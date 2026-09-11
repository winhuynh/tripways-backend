import { getServiceRoleClient } from '@shared/supabase.ts';
import { errorResponse } from '@shared/edge.ts';
import { createMemoryRateLimiter } from '@shared/rate_limit.ts';
import { createRouteSearchHandler } from './handler.ts';

const rateLimiter = createMemoryRateLimiter({ limit: 60, windowMs: 60_000 });

const handleRequest = createRouteSearchHandler(async (input) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_search_routes', {
    p_input: input,
  });
  if (error) {
    const err = new Error('ERR_ROUTE_SEARCH_QUERY_FAILED');
    Object.assign(err, {
      code: error.code,
      details: error.details,
      hint: error.hint,
      originalMessage: error.message,
    });
    throw err;
  }
  return data;
});

Deno.serve(async (request) => {
  try {
    await rateLimiter.consumeRequest('route-search', request);
    return await handleRequest(request);
  } catch (error) {
    return errorResponse(error);
  }
});
