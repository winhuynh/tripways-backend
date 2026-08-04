import { getServiceRoleClient } from '@shared/supabase.ts';
import { createPageHandler } from './handler.ts';

const handleRequest = createPageHandler(async (input) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_get_page_v2', { p_input: input });
  if (error) throw new Error('ERR_PAGE_QUERY_FAILED');
  return data;
});

Deno.serve(handleRequest);
