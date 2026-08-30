import { type EdgeLogContext, logEdgeError } from '@shared/logger.ts';

const RESPONSE_HEADERS: Record<string, string> = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
};

const CACHEABLE_RESPONSE_HEADERS: Record<string, string> = {
  'content-type': 'application/json; charset=utf-8',
  // Allow CDN (Vercel Edge, Cloudflare) and browsers to cache public read-only responses.
  // s-maxage: CDN caches for 24 h; stale-while-revalidate: serve stale while refreshing.
  'cache-control': 'public, s-maxage=86400, stale-while-revalidate=60',
};

const ERROR_STATUS: Readonly<Record<string, number>> = {
  ERR_UNAUTHORIZED: 401,
  ERR_METHOD_NOT_ALLOWED: 405,
  ERR_REQUEST_JSON_INVALID: 400,
  ERR_PROFILE_REQUEST_INVALID: 400,
  ERR_ACCOUNT_SECURITY_REQUEST_INVALID: 400,
  ERR_DELETE_ACCOUNT_REQUEST_INVALID: 400,
  ERR_ROUTE_SEARCH_INVALID_REQUEST: 400,
  ERR_ROUTE_SEARCH_CONTRACT: 500,
  ERR_ROUTE_SEARCH_QUERY_FAILED: 500,
  ERR_PAGE_INVALID_REQUEST: 400,
  ERR_PAGE_CONTRACT: 500,
  ERR_PAGE_QUERY_FAILED: 500,
  ERR_PAGE_NOT_FOUND: 404,
  ERR_PAGE_UNAVAILABLE: 503,
  ERR_HOMEPAGE_ORIGIN_CONTRACT: 500,
  ERR_HOMEPAGE_ORIGIN_QUERY_FAILED: 500,
  ERR_HOMEPAGE_STATISTICS_INVALID_REQUEST: 400,
  ERR_HOMEPAGE_STATISTICS_CONTRACT: 500,
  ERR_HOMEPAGE_STATISTICS_QUERY_FAILED: 500,
  ERR_LOCATION_SUGGEST_INVALID_REQUEST: 400,
  ERR_LOCATION_SUGGEST_CONTRACT: 500,
  ERR_INGESTION_UNAUTHORIZED: 401,
  ERR_INGESTION_INVALID_REQUEST: 400,
  ERR_INGESTION_SOURCE_NOT_ALLOWED: 403,
  ERR_INGESTION_BATCH_DUPLICATE: 409,
  ERR_INGESTION_VALIDATION_FAILED: 422,
  ERR_INGESTION_NO_USABLE_PRICES: 422,
  ERR_INGESTION_ANOMALY_REVIEW_REQUIRED: 409,
  ERR_INGESTION_PUBLISH_FAILED: 500,
  ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST: 400,
  ERR_FLIGHT_ROUTE_CACHE_UNAVAILABLE: 503,
  ERR_FLIGHT_AFFILIATE_HANDOFF_INVALID_REQUEST: 400,
  ERR_HANDOFF_UNAVAILABLE: 404,
  ERR_INVALID_REQUEST: 400,
  ERR_AUTH_EMAIL_REQUIRED: 400,
  ERR_DISPLAY_NAME_INVALID: 400,
  ERR_EMAIL_INVALID: 400,
  ERR_PASSWORD_INVALID: 400,
  ERR_CURRENT_PASSWORD_REQUIRED: 400,
  ERR_INVALID_CURRENT_PASSWORD: 401,
  ERR_AUTH_PASSWORD_UPDATE_FAILED: 400,
  ERR_AUTH_EMAIL_UPDATE_FAILED: 400,
  ERR_AUTH_SESSION_REVOCATION_FAILED: 500,
  ERR_ACCOUNT_DELETE_FAILED: 500,
  ERR_RATE_LIMITED: 429,
  ERR_USER_PROFILE_NOT_FOUND: 404,
  ERR_AIRPORT_NOT_FOUND: 404,
  ERR_CITY_NOT_FOUND: 404,
};

export function jsonResponse(
  value: unknown,
  status = 200,
  extraHeaders?: Record<string, string>,
): Response {
  const headers = extraHeaders ? { ...RESPONSE_HEADERS, ...extraHeaders } : RESPONSE_HEADERS;
  return new Response(JSON.stringify(value), { status, headers });
}

export function cacheableJsonResponse(
  value: unknown,
  status = 200,
  extraHeaders?: Record<string, string>,
): Response {
  const headers = extraHeaders
    ? { ...CACHEABLE_RESPONSE_HEADERS, ...extraHeaders }
    : CACHEABLE_RESPONSE_HEADERS;
  return new Response(JSON.stringify(value), {
    status,
    headers,
  });
}

export function successResponse(
  data: unknown,
  status = 200,
  extraHeaders?: Record<string, string>,
): Response {
  return jsonResponse({ data, error: null }, status, extraHeaders);
}

/** Use for public, anonymous, read-only endpoints that can be cached by CDN and browsers. */
export function cacheableSuccessResponse(
  data: unknown,
  status = 200,
  extraHeaders?: Record<string, string>,
): Response {
  return cacheableJsonResponse({ data, error: null }, status, extraHeaders);
}

export function errorResponse(
  error: unknown,
  context?: EdgeLogContext,
  extraHeaders?: Record<string, string>,
): Response {
  const candidate = error instanceof Error ? error.message : '';
  const code = candidate in ERROR_STATUS ? candidate : 'ERR_INTERNAL';

  // Log technical error with full context before sanitizing for response
  logEdgeError('EDGE_REQUEST_ERROR', error, {
    ...context,
    errorCode: code,
  });

  const responseHeaders = context?.requestId
    ? { 'x-request-id': context.requestId, ...extraHeaders }
    : extraHeaders;

  return jsonResponse(
    { data: null, error: { code } },
    ERROR_STATUS[code] ?? 500,
    responseHeaders,
  );
}

export function assertMethod(
  request: Request,
  allowedMethods: readonly string[],
  context?: EdgeLogContext,
): Response | null {
  if (allowedMethods.includes(request.method)) return null;
  return errorResponse(new Error('ERR_METHOD_NOT_ALLOWED'), context);
}

export async function readJson(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    throw new Error('ERR_REQUEST_JSON_INVALID');
  }
}
