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
      if (
        airportList.length === 0 &&
        (payload.scope === 'top_hubs' || payload.scope === 'top_airports')
      ) {
        const targetLimit = payload.limit ?? 80;
        const { data, error } = await supabaseClient
          .from('airports')
          .select('iata')
          .eq('status', 'active')
          .not('iata', 'is', null)
          .or('is_hub.eq.true,airport_type.eq.large_airport')
          .order('is_hub', { ascending: false })
          .limit(targetLimit);

        if (error) {
          throw new Error(`ERR_DB_AIRPORTS_LOOKUP_FAILED: ${error.message}`);
        }
        airportList = (data ?? []).map((r: { iata: string }) => r.iata).filter(Boolean);
      }

      return await ingestDirectRoutesForAirports(
        airportList,
        {
          apiKey: aerodataboxApiKey,
          delayMs: 250,
        },
        supabaseClient,
      );
    },
    log(event) {
      console.log(JSON.stringify(event));
    },
  });
});
