import { getServiceRoleClient } from '@shared/supabase.ts';
import { createRouteSearchHandler } from './handler.ts';

const handleRequest = createRouteSearchHandler(async (input) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_search_routes', {
    p_input: input,
  });
  if (error) {
    const err = new Error('ERR_ROUTE_SEARCH_QUERY_FAILED');
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

Deno.serve(handleRequest);
