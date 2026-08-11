import { isRecord } from './guards.ts';

export type RpcEnvelope = {
  data: unknown;
  meta: Record<string, unknown> & { data_version: string };
  error: null;
};

export function mapRpcEnvelope(value: unknown, errorCode: string): RpcEnvelope {
  if (!isRecord(value) || !('data' in value) || !('error' in value)) {
    throw new Error(errorCode);
  }
  if (value.error !== null) {
    if (
      isRecord(value.error) &&
      typeof value.error.code === 'string' &&
      /^ERR_[A-Z0-9_]+$/.test(value.error.code)
    ) {
      throw new Error(value.error.code);
    }
    throw new Error(errorCode);
  }
  if (!isRecord(value.meta)) throw new Error(errorCode);
  if (typeof value.meta.data_version !== 'string' || value.meta.data_version.length === 0) {
    throw new Error(errorCode);
  }
  return value as RpcEnvelope;
}
