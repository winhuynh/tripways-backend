import { getServiceRoleClient } from '@shared/supabase.ts';
import { handlePriceEstimateIngestionRequest } from './handler.ts';
import {
  executePriceEstimateIngestion,
  type PriceEstimateAdapter,
  type PriceEstimatePublicationResult,
} from './service.ts';
import { createTravelpayoutsAdapter } from './providers/travelpayouts-provider.ts';

Deno.serve((request) =>
  handlePriceEstimateIngestionRequest(request, {
    workerSecret: requiredEnv('INGESTION_WORKER_SECRET'),
    execute: (input) =>
      executePriceEstimateIngestion(input, adapterRegistry(), async (args) => {
        const { data, error } = await getServiceRoleClient().rpc(
          'rpc_publish_price_estimate_batch',
          { ...args, p_publication_source_type: publicationSourceType() },
        );
        if (error || !isResult(data)) throw new Error('ERR_INGESTION_PUBLISH_FAILED');
        return data;
      }),
  })
);

function adapterRegistry(): ReadonlyMap<string, PriceEstimateAdapter> {
  const adapters = new Map<string, PriceEstimateAdapter>([['fixture', {
    load: () =>
      Promise.resolve({
        ok: true as const,
        batch: {
          schemaVersion: 'flight-content-observations.v1' as const,
          sourceTime: null,
          observations: [],
        },
      }),
  }]]);
  const token = Deno.env.get('TRAVELPAYOUTS_TOKEN')?.trim();
  if (token) {
    const origins = (Deno.env.get('TRAVELPAYOUTS_ORIGINS') ?? '')
      .split(',').map((value) => value.trim().toUpperCase())
      .filter((value) => /^[A-Z]{3}$/.test(value));
    if (origins.length > 0) {
      adapters.set(
        'travelpayouts',
        createTravelpayoutsAdapter({
          token,
          origins,
          currencyCode: (Deno.env.get('TRAVELPAYOUTS_CURRENCY') ?? 'USD').toUpperCase(),
          marketCode: (Deno.env.get('TRAVELPAYOUTS_MARKET') ?? 'us').toLowerCase(),
          locale: Deno.env.get('TRAVELPAYOUTS_LOCALE') ?? 'en-GB',
        }),
      );
    }
  }
  return adapters;
}
function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error('ERR_SERVER_CONFIGURATION');
  return value;
}
function publicationSourceType(): 'development_fixture' | 'staging' | 'production' {
  const value = requiredEnv('PUBLICATION_SOURCE_TYPE');
  if (value !== 'development_fixture' && value !== 'staging' && value !== 'production') {
    throw new Error('ERR_SERVER_CONFIGURATION');
  }
  return value;
}
function isResult(value: unknown): value is PriceEstimatePublicationResult {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return typeof row.status === 'string' && typeof row.acceptedCount === 'number' &&
    typeof row.rejectedCount === 'number' &&
    (row.errorCode === null || typeof row.errorCode === 'string');
}
