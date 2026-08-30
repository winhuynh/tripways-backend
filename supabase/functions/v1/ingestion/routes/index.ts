import { createClient } from '@supabase/supabase-js';
import { handleRouteIngestionRequest } from './handler.ts';
import { ingestDirectRoutesForAirports } from './service.ts';

Deno.serve(async (req) => {
  const workerSecret = Deno.env.get('SERVICE_ROLE_KEY') ?? '';
  const aerodataboxApiKey = Deno.env.get('AERODATABOX_API_KEY') ?? '';
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';

  const supabaseClient = createClient(supabaseUrl, workerSecret);

  return await handleRouteIngestionRequest(req, {
    workerSecret,
    async execute(payload) {
      return await ingestDirectRoutesForAirports(
        payload.airports,
        { apiKey: aerodataboxApiKey },
        supabaseClient,
      );
    },
    log(event) {
      console.log(JSON.stringify(event));
    },
  });
});
