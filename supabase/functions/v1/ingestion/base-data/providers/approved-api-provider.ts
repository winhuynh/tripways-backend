import { parseCanonicalBaseDataBatch, type ProviderResult } from '../provider-contract.ts';

export type ApprovedApiProviderConfig = {
  baseUrl: string;
  maxRecords: number;
  fetcher?: typeof fetch;
};

export async function loadApprovedApiProvider(
  config: ApprovedApiProviderConfig,
): Promise<ProviderResult> {
  let url: URL;
  try {
    url = new URL(config.baseUrl);
  } catch {
    return invalidConfiguration();
  }
  if (
    url.protocol !== 'https:' ||
    !Number.isInteger(config.maxRecords) ||
    config.maxRecords < 1 ||
    config.maxRecords > 100
  ) {
    return invalidConfiguration();
  }

  url.searchParams.set('limit', String(config.maxRecords));
  let response: Response;
  try {
    response = await (config.fetcher ?? fetch)(url);
  } catch {
    return invalidConfiguration();
  }
  if (!response.ok) return invalidConfiguration();

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    return invalidConfiguration();
  }

  const parsed = parseCanonicalBaseDataBatch(payload);
  if (!parsed.ok) return parsed;
  const recordCount = parsed.batch.countries.length + parsed.batch.cities.length +
    parsed.batch.airports.length;
  if (recordCount > config.maxRecords) {
    return {
      ok: false,
      issues: [{ code: 'ERR_PROVIDER_RECORD_LIMIT', recordType: 'batch', sourceKey: null }],
    };
  }
  return parsed;
}

function invalidConfiguration(): ProviderResult {
  return {
    ok: false,
    issues: [{ code: 'ERR_INVALID_PROVIDER_PAYLOAD', recordType: 'batch', sourceKey: null }],
  };
}
