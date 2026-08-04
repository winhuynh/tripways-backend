import { getServiceRoleClient } from '@shared/supabase.ts';
import { createRouteSearchHandler } from './handler.ts';

const handleRequest = createRouteSearchHandler(async (input) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_search_route_options_v2', {
    p_input: input,
  });
  if (error) throw new Error('ERR_ROUTE_SEARCH_QUERY_FAILED');
  return data;
});

Deno.serve(handleRequest);
