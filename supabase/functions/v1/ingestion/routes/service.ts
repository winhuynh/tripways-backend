import {
  type AeroDataBoxConfig,
  type AeroDataBoxRoute,
  fetchDirectRoutesFromAeroDataBox,
} from './providers/aerodatabox-provider.ts';

export interface RouteIngestionDbClient {
  rpc(
    functionName: string,
    args: Record<string, unknown>,
  ): Promise<{ data: unknown; error: { message: string; code?: string } | null }>;
}

export interface IngestRoutesResult {
  status: 'success' | 'partial_failure';
  total_airports_processed: number;
  total_routes_upserted: number;
  results: {
    origin_iata: string;
    route_count: number;
    upserted_count: number;
  }[];
  errors: {
    origin_iata: string;
    error: string;
  }[];
}

export async function ingestDirectRoutesForAirports(
  airportIatas: string[],
  config: AeroDataBoxConfig,
  dbClient: RouteIngestionDbClient,
): Promise<IngestRoutesResult> {
  const uniqueIatas = Array.from(
    new Set(airportIatas.map((i) => i.trim().toUpperCase()).filter((i) => i.length === 3)),
  );

  if (uniqueIatas.length === 0) {
    return {
      status: 'success',
      total_airports_processed: 0,
      total_routes_upserted: 0,
      results: [],
      errors: [],
    };
  }

  let totalUpserted = 0;
  const results: IngestRoutesResult['results'] = [];
  const errors: IngestRoutesResult['errors'] = [];

  for (const iata of uniqueIatas) {
    try {
      const routes: AeroDataBoxRoute[] = await fetchDirectRoutesFromAeroDataBox(iata, config);

      if (routes.length === 0) {
        results.push({ origin_iata: iata, route_count: 0, upserted_count: 0 });
        continue;
      }

      const { data, error } = await dbClient.rpc('rpc_ingest_direct_flight_routes', {
        p_source_code: 'aerodatabox',
        p_routes: routes,
      });

      if (error) {
        throw new Error(error.message);
      }

      const upserted = (data as { upserted_count?: number })?.upserted_count ?? routes.length;
      totalUpserted += upserted;

      results.push({
        origin_iata: iata,
        route_count: routes.length,
        upserted_count: upserted,
      });
    } catch (err) {
      errors.push({
        origin_iata: iata,
        error: (err as Error).message || 'Unknown ingestion error',
      });
    }
  }

  return {
    status: errors.length === 0 ? 'success' : 'partial_failure',
    total_airports_processed: uniqueIatas.length,
    total_routes_upserted: totalUpserted,
    results,
    errors,
  };
}
