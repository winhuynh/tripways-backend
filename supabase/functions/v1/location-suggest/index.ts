import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createSupabaseClient } from '@shared/supabase.ts';
import { createLocationSuggestHandler } from './handler.ts';
import type { LocationSuggestRequest } from './request.ts';

const client = createSupabaseClient();

const handler = createLocationSuggestHandler(async (input: LocationSuggestRequest) => {
  const { data, error } = await client.rpc('rpc_suggest_locations', {
    p_input: input,
  });

  if (error) {
    throw error;
  }

  return data;
});

serve(handler);
