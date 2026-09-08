import { getServiceRoleClient } from '@shared/supabase.ts';
import { errorResponse } from '@shared/edge.ts';
import { createMemoryRateLimiter } from '@shared/rate_limit.ts';
import {
  createAffiliateHandoffHandler,
  DEFAULT_DISCLOSURE,
  isAllowlistedAviasalesUrl,
} from './handler.ts';

const rateLimiter = createMemoryRateLimiter({ limit: 30, windowMs: 60_000 });

const handler = createAffiliateHandoffHandler(async (observationRef) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_get_flight_affiliate_handoff', {
    p_observation_ref: observationRef,
  });
  if (error || typeof data !== 'object' || data === null || Array.isArray(data)) {
    return { data: null, error: true };
  }
  const envelope = data as {
    data?: { url?: unknown; expires_at?: unknown; disclosure?: unknown } | null;
    error?: unknown;
  };
  if (
    !envelope.data ||
    typeof envelope.data.url !== 'string' ||
    !isAllowlistedAviasalesUrl(envelope.data.url) ||
    typeof envelope.data.expires_at !== 'string'
  ) {
    return { data: null, error: true };
  }
  return {
    data: {
      url: envelope.data.url,
      expires_at: envelope.data.expires_at,
      disclosure: typeof envelope.data.disclosure === 'string'
        ? envelope.data.disclosure
        : DEFAULT_DISCLOSURE,
    },
    error: null,
  };
});

Deno.serve(async (request) => {
  try {
    const subject = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
    rateLimiter.consume(subject);
    return await handler(request);
  } catch (error) {
    return errorResponse(error);
  }
});
