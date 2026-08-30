import { getServiceRoleClient } from '@shared/supabase.ts';
import { createLocationSuggestHandler } from './handler.ts';
import type { LocationSuggestRequest } from './request.ts';

const handleRequest = createLocationSuggestHandler(async (input: LocationSuggestRequest) => {
  const { data, error } = await getServiceRoleClient().rpc('rpc_suggest_locations', {
    p_input: input,
  });

  if (error) {
    const err = new Error('ERR_LOCATION_SUGGEST_QUERY_FAILED');
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
