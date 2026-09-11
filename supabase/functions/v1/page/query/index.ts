import { getServiceRoleClient } from '@shared/supabase.ts';
import { errorResponse } from '@shared/edge.ts';
import { createMemoryRateLimiter } from '@shared/rate_limit.ts';
import { createPageHandler } from './handler.ts';

const rateLimiter = createMemoryRateLimiter({ limit: 120, windowMs: 60_000 });

const handleRequest = createPageHandler(async (input) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_get_page', { p_input: input });
  if (error) {
    const err = new Error('ERR_PAGE_QUERY_FAILED');
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
    await rateLimiter.consumeRequest('page-query', request);
    return await handleRequest(request);
  } catch (error) {
    return errorResponse(error);
  }
});
