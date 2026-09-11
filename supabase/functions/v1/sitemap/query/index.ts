import { getServiceRoleClient } from '@shared/supabase.ts';
import { errorResponse } from '@shared/edge.ts';
import { createMemoryRateLimiter } from '@shared/rate_limit.ts';
import { handleSitemapQuery } from './handler.ts';

const rateLimiter = createMemoryRateLimiter({ limit: 30, windowMs: 60_000 });

Deno.serve(async (request) => {
  try {
    await rateLimiter.consumeRequest('sitemap-query', request);
    return await handleSitemapQuery(request, {
      query: async (locale) => {
        const { data, error } = await getServiceRoleClient().rpc('rpc_get_sitemap', {
          p_input: locale ? { locale } : {},
        });
        if (error) throw new Error('ERR_SITEMAP_QUERY_FAILED');
        return data;
      },
    });
  } catch (error) {
    return errorResponse(error);
  }
});
