import { handleAirportPageQuery } from './handler.ts';

const RPC_BY_ACTION = {
  get_page: 'rpc_get_airport_page',
  search_routes: 'rpc_search_airport_direct_routes',
} as const;

Deno.serve((request) =>
  handleAirportPageQuery(request, {
    query: async (action, input) => {
      const supabaseUrl = readRequiredEnv('SUPABASE_URL').replace(/\/$/, '');
      const serviceRoleKey = readRequiredEnv('SUPABASE_SERVICE_ROLE_KEY');
      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${RPC_BY_ACTION[action]}`, {
        method: 'POST',
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ p_input: input }),
      });
      if (!response.ok) throw new Error('ERR_AIRPORT_PAGE_UNAVAILABLE');
      return await response.json();
    },
  })
);

function readRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error('ERR_AIRPORT_PAGE_UNAVAILABLE');
  return value;
}
