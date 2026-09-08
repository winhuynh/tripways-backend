import {
  type AeroDataBoxConfig,
  type AeroDataBoxRoute,
  fetchDirectRoutesFromAeroDataBox,
} from './providers/aerodatabox-provider.ts';

export interface RouteIngestionDbClient {
  rpc(
    functionName: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: { message: string; code?: string } | null }>;
}

export interface IngestRoutesResult {
  status: 'success' | 'partial_failure';
  total_airports_processed: number;
  total_routes_upserted: number;
  total_routes_purged: number;
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
      total_routes_purged: 0,
      results: [],
      errors: [],
    };
  }

  let totalUpserted = 0;
  const results: IngestRoutesResult['results'] = [];
  const errors: IngestRoutesResult['errors'] = [];
  const delayMs = config.delayMs ?? 0;

  for (const [i, iata] of uniqueIatas.entries()) {
    try {
      if (delayMs > 0 && i > 0) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }

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

  // Enforce 7-day TTL: purge expired routes older than 7 days (ToS Article 5.5)
  let totalPurged = 0;
  try {
    const { data: purgeData, error: purgeError } = await dbClient.rpc(
      'rpc_purge_expired_direct_flight_routes',
      {
        p_source_code: 'aerodatabox',
        p_retention_interval: '7 days',
      },
    );
    if (!purgeError && purgeData && typeof purgeData === 'object') {
      totalPurged = (purgeData as { deleted_count?: number }).deleted_count ?? 0;
    }
  } catch {
    // Purge failure should not fail overall ingestion status
  }

  // Link batch ingestion to publication (Finding R5)
  if (totalUpserted > 0 || totalPurged > 0) {
    try {
      await dbClient.rpc('publish_read_model_version', { p_allow_empty: true });
    } catch {
      // Publication failure should not fail overall ingestion
    }
  }

  return {
    status: errors.length === 0 ? 'success' : 'partial_failure',
    total_airports_processed: uniqueIatas.length,
    total_routes_upserted: totalUpserted,
    total_routes_purged: totalPurged,
    results,
    errors,
  };
}
