import { getServiceRoleClient } from '@shared/supabase.ts';
import { errorResponse } from '@shared/edge.ts';
import { createMemoryRateLimiter } from '@shared/rate_limit.ts';
import { createAirportRoutesCacheHandler } from './handler.ts';

const rateLimiter = createMemoryRateLimiter({ limit: 60, windowMs: 60_000 });

const handler = createAirportRoutesCacheHandler({
  getSupabaseClient: () => getServiceRoleClient(),
});

Deno.serve(async (request) => {
  try {
    await rateLimiter.consumeRequest('airport-routes-cache', request);
    return await handler(request);
  } catch (error) {
    return errorResponse(error);
  }
});
