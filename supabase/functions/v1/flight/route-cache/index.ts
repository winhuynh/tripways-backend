import { getServiceRoleClient } from '@shared/supabase.ts';
import { errorResponse } from '@shared/edge.ts';
import { buildRateLimitSubjectHashes } from '@shared/rate_limit.ts';
import { createRouteCacheHandler } from './handler.ts';

const attempts = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 60;
const RATE_WINDOW_MS = 60_000;

async function consumeRateLimit(request: Request): Promise<void> {
  const [, ipHash] = await buildRateLimitSubjectHashes('route-cache', request);
  const now = Date.now();
  const current = attempts.get(ipHash);
  if (!current || current.resetAt <= now) {
    if (attempts.size >= 10_000) attempts.clear();
    attempts.set(ipHash, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return;
  }
  if (current.count >= RATE_LIMIT) throw new Error('ERR_RATE_LIMITED');
  current.count += 1;
}

const handler = createRouteCacheHandler({
  getSupabaseClient: () => getServiceRoleClient(),
});

Deno.serve(async (request) => {
  try {
    await consumeRateLimit(request);
    return await handler(request);
  } catch (error) {
    return errorResponse(error);
  }
});
