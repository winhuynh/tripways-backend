import { getServiceRoleClient } from '@shared/supabase.ts';
import { handleRouteQuery, type RouteSearchEnvelope } from './handler.ts';

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID();
  const response = await handleRouteQuery(request, {
    searchRoutes: async (input) => {
      const result = await getServiceRoleClient().rpc('rpc_search_routes', {
        p_input: input,
      });
      if (result.error) throw new Error('ERR_INTERNAL');
      return result.data as RouteSearchEnvelope;
    },
  });

  console.info(JSON.stringify({
    request_id: requestId,
    action: 'ROUTE_DISCOVERY_QUERY',
    status: response.status,
    processed_at: new Date().toISOString(),
    error_code: response.status >= 500 ? 'ERR_INTERNAL' : null,
  }));

  return response;
});
