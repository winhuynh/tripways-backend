import { getServiceRoleClient } from '@shared/supabase.ts';
import { createHomepageOriginHandler } from './handler.ts';

const handleRequest = createHomepageOriginHandler(async (input) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_resolve_homepage_origin', {
    p_input: input,
  });
  if (error) throw new Error('ERR_HOMEPAGE_ORIGIN_QUERY_FAILED');
  return data;
});

Deno.serve(handleRequest);
