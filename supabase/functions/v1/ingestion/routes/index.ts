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
      let airportList = payload.airports ?? [];
      if (airportList.length === 0 && payload.scope === 'top_airports') {
        const { data, error } = await supabaseClient
          .from('airports')
          .select('iata')
          .or('airport_type.eq.large_airport,is_hub.eq.true')
          .not('iata', 'is', null)
          .limit(payload.limit ?? 350);

        if (error) {
          throw new Error(`ERR_DB_AIRPORTS_LOOKUP_FAILED: ${error.message}`);
        }
        airportList = (data ?? []).map((r: { iata: string }) => r.iata).filter(Boolean);
      }

      return await ingestDirectRoutesForAirports(
        airportList,
        { apiKey: aerodataboxApiKey },
        supabaseClient,
      );
    },
    log(event) {
      console.log(JSON.stringify(event));
    },
  });
});
