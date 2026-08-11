import { getServiceRoleClient } from '@shared/supabase.ts';
import { handleBaseDataIngestionRequest } from './handler.ts';
import { loadApprovedApiProvider } from './providers/approved-api-provider.ts';
import { loadFixtureProvider } from './providers/fixture-provider.ts';
import { loadOurAirportsProvider } from './providers/ourairports-provider.ts';
import { executeBaseDataIngestion, type PublicationResult } from './service.ts';

const attempts = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 10;
const RATE_WINDOW_MS = 60_000;

Deno.serve((request) =>
  handleBaseDataIngestionRequest(request, {
    workerSecret: readRequiredEnv('INGESTION_WORKER_SECRET'),
    rateLimit: consumeLocalRateLimit,
    execute: (input) =>
      executeBaseDataIngestion(input, {
        loadFixture: loadFixtureProvider,
        loadApprovedApi: () =>
          loadApprovedApiProvider({
            baseUrl: readRequiredEnv('APPROVED_BASE_DATA_API_URL'),
            maxRecords: readBoundedRecordLimit(),
          }),
        loadOurAirports: async () => {
          const client = getServiceRoleClient();
          const { data, error } = await client.rpc('rpc_get_ourairports_denylist');
          if (error || !Array.isArray(data) || data.some((value) => typeof value !== 'string')) {
            throw new Error('ERR_SERVER_CONFIGURATION');
          }
          return await loadOurAirportsProvider({
            airportsUrl: 'https://davidmegginson.github.io/ourairports-data/airports.csv',
            denylist: new Set(data),
            maxDownloadBytes: 25_000_000,
          });
        },
        publish: async (arguments_) => {
          const { data, error } = await getServiceRoleClient().rpc(
            'rpc_publish_base_data_batch',
            arguments_,
          );
          if (error || !isPublicationResult(data)) {
            throw new Error('ERR_INGESTION_PUBLISH_FAILED');
          }
          return data;
        },
      }),
    log: (event) => console.info(JSON.stringify(event)),
  })
);

function consumeLocalRateLimit(subjectHash: string): Promise<void> {
  const now = Date.now();
  const current = attempts.get(subjectHash);
  if (!current || current.resetAt <= now) {
    attempts.set(subjectHash, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return Promise.resolve();
  }
  if (current.count >= RATE_LIMIT) throw new Error('ERR_RATE_LIMITED');
  current.count += 1;
  return Promise.resolve();
}

function readRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error('ERR_SERVER_CONFIGURATION');
  return value;
}

function readBoundedRecordLimit(): number {
  const value = Number(readRequiredEnv('APPROVED_BASE_DATA_API_MAX_RECORDS'));
  if (!Number.isInteger(value) || value < 1 || value > 100) {
    throw new Error('ERR_SERVER_CONFIGURATION');
  }
  return value;
}

function isPublicationResult(value: unknown): value is PublicationResult {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const result = value as Record<string, unknown>;
  return (
    typeof result.status === 'string' &&
    typeof result.acceptedCount === 'number' &&
    typeof result.rejectedCount === 'number' &&
    (typeof result.errorCode === 'string' || result.errorCode === null)
  );
}
