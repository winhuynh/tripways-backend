import { handleCityPageQuery } from './handler.ts';
import type { CityPageAction } from './request.ts';

const RPC_BY_ACTION: Readonly<Record<CityPageAction, string>> = {
  get_overview: 'rpc_get_city_overview',
  get_airports: 'rpc_get_city_airports',
  get_quick_facts: 'rpc_get_city_quick_facts',
  get_destinations: 'rpc_search_city_direct_routes',
  get_airlines: 'rpc_get_city_airlines',
  get_insights: 'rpc_get_city_insights',
  get_internal_links: 'rpc_get_city_internal_links',
  get_faqs: 'rpc_get_city_faqs',
};

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID();
  const response = await handleCityPageQuery(request, {
    query: async (action, input) => {
      const supabaseUrl = readRequiredEnv('SUPABASE_URL').replace(/\/$/, '');
      const serviceRoleKey = readRequiredEnv('SUPABASE_SERVICE_ROLE_KEY');
      const rpcResponse = await fetch(`${supabaseUrl}/rest/v1/rpc/${RPC_BY_ACTION[action]}`, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ p_input: input }),
      });

      if (!rpcResponse.ok) throw new Error('ERR_CITY_PAGE_UNAVAILABLE');
      return await rpcResponse.json();
    },
  });

  console.info(JSON.stringify({
    request_id: requestId,
    action: 'CITY_PAGE_QUERY',
    status: response.status,
    processed_at: new Date().toISOString(),
    error_code: response.status >= 500 ? 'ERR_INTERNAL' : null,
  }));

  return response;
});

function readRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error('ERR_CITY_PAGE_UNAVAILABLE');
  return value;
}
