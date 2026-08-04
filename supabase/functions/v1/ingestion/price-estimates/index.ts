import { getServiceRoleClient } from '@shared/supabase.ts';
import { handlePriceEstimateIngestionRequest } from './handler.ts';
import {
  executePriceEstimateIngestion,
  type PriceEstimateAdapter,
  type PriceEstimatePublicationResult,
} from './service.ts';

Deno.serve((request) =>
  handlePriceEstimateIngestionRequest(request, {
    workerSecret: requiredEnv('INGESTION_WORKER_SECRET'),
    execute: (input) =>
      executePriceEstimateIngestion(input, adapterRegistry(), async (args) => {
        const { data, error } = await getServiceRoleClient().rpc(
          'rpc_publish_price_estimate_batch',
          args,
        );
        if (error || !isResult(data)) throw new Error('ERR_INGESTION_PUBLISH_FAILED');
        return data;
      }),
  })
);

function adapterRegistry(): ReadonlyMap<string, PriceEstimateAdapter> {
  return new Map([['fixture', {
    load: () =>
      Promise.resolve({
        ok: true as const,
        batch: {
          schemaVersion: 'route-price-estimates.v1' as const,
          sourceTime: null,
          estimates: [],
        },
      }),
  }]]);
}
function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error('ERR_SERVER_CONFIGURATION');
  return value;
}
function isResult(value: unknown): value is PriceEstimatePublicationResult {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const row = value as Record<string, unknown>;
  return typeof row.status === 'string' && typeof row.acceptedCount === 'number' &&
    typeof row.rejectedCount === 'number' &&
    (row.errorCode === null || typeof row.errorCode === 'string');
}
