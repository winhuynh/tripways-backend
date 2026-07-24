import { handleRouteQuery } from './handler.ts';

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID();
  const response = await handleRouteQuery(request, {
    searchRoutes: async (input) => {
      const supabaseUrl = readRequiredEnv('SUPABASE_URL').replace(/\/$/, '');
      const serviceRoleKey = readRequiredEnv('SUPABASE_SERVICE_ROLE_KEY');
      const rpcResponse = await fetch(`${supabaseUrl}/rest/v1/rpc/rpc_search_routes`, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ p_input: input }),
      });
      if (!rpcResponse.ok) throw new Error('ERR_ROUTE_DISCOVERY_UNAVAILABLE');
      return await rpcResponse.json();
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

function readRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error('ERR_ROUTE_DISCOVERY_UNAVAILABLE');
  return value;
}
