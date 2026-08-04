import { isRecord } from './guards.ts';

export type RpcEnvelope = {
  data: unknown;
  meta: Record<string, unknown> & { data_version: string };
  error: null;
};

export function mapRpcEnvelope(value: unknown, errorCode: string): RpcEnvelope {
  if (!isRecord(value) || value.error !== null || !('data' in value) || !isRecord(value.meta)) {
    throw new Error(errorCode);
  }
  if (typeof value.meta.data_version !== 'string' || value.meta.data_version.length === 0) {
    throw new Error(errorCode);
  }
  return value as RpcEnvelope;
}
