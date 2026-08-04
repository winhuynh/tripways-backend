import { getServiceRoleClient } from '@shared/supabase.ts';
import { handleSitemapQuery } from './handler.ts';
Deno.serve((request) =>
  handleSitemapQuery(request, {
    query: async (locale) => {
      const { data, error } = await getServiceRoleClient().rpc('rpc_get_sitemap', {
        p_input: locale ? { locale } : {},
      });
      if (error) throw new Error('ERR_SITEMAP_QUERY_FAILED');
      return data;
    },
  })
);
