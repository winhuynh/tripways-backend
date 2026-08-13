import { assertMethod, errorResponse, jsonResponse, readJson } from '@shared/edge.ts';
import type { RateLimitDecision } from '@shared/rate_limit.ts';
import { parseRouteCacheRequest, type RouteCacheRequest } from './request.ts';

type RouteCacheEnvelope = {
  data: { status: string; routes: unknown[] };
  meta: Record<string, unknown>;
  error: null;
};

export async function handleRouteCacheRequest(
  request: Request,
  dependencies: {
    workerSecret?: string;
    consume(subjectHash: string): Promise<RateLimitDecision>;
    execute(input: RouteCacheRequest, allowRefresh: boolean): Promise<RouteCacheEnvelope>;
  },
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;

  try {
    const input = parseRouteCacheRequest(await readJson(request));
    const trustedWorker = dependencies.workerSecret !== undefined &&
      dependencies.workerSecret.length >= 16 &&
      request.headers.get('authorization') === `Bearer ${dependencies.workerSecret}`;
    const allowRefresh = trustedWorker || !isCrawler(request.headers.get('user-agent'));
    if (allowRefresh && !trustedWorker) {
      const decision = await dependencies.consume(await requestSubjectHash(request));
      if (!decision.allowed) throw new Error('ERR_RATE_LIMITED');
    }
    return jsonResponse(await dependencies.execute(input, allowRefresh));
  } catch (error) {
    return errorResponse(error);
  }
}

function isCrawler(userAgent: string | null): boolean {
  return /bot|crawler|spider|slurp|bingpreview/i.test(userAgent ?? '');
}

async function requestSubjectHash(request: Request): Promise<string> {
  const forwarded = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  const value = forwarded || 'local-unknown';
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(`flight-route-cache:${value}`),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}
