import fixture from '../fixtures/base-data-v1.json' with { type: 'json' };
import { parseCanonicalBaseDataBatch, type ProviderResult } from '../provider-contract.ts';

export function loadFixtureProvider(): Promise<ProviderResult> {
  return Promise.resolve(parseCanonicalBaseDataBatch(structuredClone(fixture)));
}
