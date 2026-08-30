import { getServiceRoleClient } from '@shared/supabase.ts';
import { createPageHandler } from './handler.ts';

const handleRequest = createPageHandler(async (input) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_get_page', { p_input: input });
  if (error) {
    const err = new Error('ERR_PAGE_QUERY_FAILED');
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
