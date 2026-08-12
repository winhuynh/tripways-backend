import { getServiceRoleClient } from '@shared/supabase.ts';
import { createHomepageStatisticsHandler } from './handler.ts';

const handleRequest = createHomepageStatisticsHandler(async () => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_get_homepage_statistics');
  if (error) throw new Error('ERR_HOMEPAGE_STATISTICS_QUERY_FAILED');
  return data;
});

Deno.serve(handleRequest);
