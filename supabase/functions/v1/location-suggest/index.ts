import { getServiceRoleClient } from '@shared/supabase.ts';
import { errorResponse } from '@shared/edge.ts';
import { createMemoryRateLimiter } from '@shared/rate_limit.ts';
import { createLocationSuggestHandler } from './handler.ts';
import type { LocationSuggestRequest } from './request.ts';

const rateLimiter = createMemoryRateLimiter({ limit: 60, windowMs: 60_000 });

const handleRequest = createLocationSuggestHandler(async (input: LocationSuggestRequest) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_suggest_locations', {
    p_input: input,
  });

  if (error) {
    const err = new Error('ERR_LOCATION_SUGGEST_QUERY_FAILED');
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
    await rateLimiter.consumeRequest('location-suggest', request);
    return await handleRequest(request);
  } catch (error) {
    return errorResponse(error);
  }
});
