const RESPONSE_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
};

const ERROR_STATUS: Readonly<Record<string, number>> = {
  ERR_UNAUTHORIZED: 401,
  ERR_METHOD_NOT_ALLOWED: 405,
  ERR_REQUEST_JSON_INVALID: 400,
  ERR_PROFILE_REQUEST_INVALID: 400,
  ERR_ACCOUNT_SECURITY_REQUEST_INVALID: 400,
  ERR_DELETE_ACCOUNT_REQUEST_INVALID: 400,
  ERR_ROUTE_SEARCH_REQUEST_INVALID: 400,
  ERR_ROUTE_DISCOVERY_INVALID_REQUEST: 400,
  ERR_ROUTE_DISCOVERY_CONTRACT: 500,
  ERR_ROUTE_DISCOVERY_UNAVAILABLE: 503,
  ERR_CITY_PAGE_INVALID_REQUEST: 400,
  ERR_CITY_PAGE_CONTRACT: 500,
  ERR_CITY_PAGE_UNAVAILABLE: 503,
  ERR_AIRPORT_PAGE_INVALID_REQUEST: 400,
  ERR_AIRPORT_PAGE_CONTRACT: 500,
  ERR_AIRPORT_PAGE_UNAVAILABLE: 503,
  ERR_AIRPORT_PAGE_NOT_FOUND: 404,
  ERR_INGESTION_UNAUTHORIZED: 401,
  ERR_INGESTION_INVALID_REQUEST: 400,
  ERR_INGESTION_SOURCE_NOT_ALLOWED: 403,
  ERR_INGESTION_BATCH_DUPLICATE: 409,
  ERR_INGESTION_VALIDATION_FAILED: 422,
  ERR_INGESTION_PUBLISH_FAILED: 500,
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
  ERR_CITY_PAGE_NOT_FOUND: 404,
};

export function jsonResponse(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), { status, headers: RESPONSE_HEADERS });
}

export function successResponse(data: unknown, status = 200): Response {
  return jsonResponse({ data, error: null }, status);
}

export function errorResponse(error: unknown): Response {
  const candidate = error instanceof Error ? error.message : '';
  const code = candidate in ERROR_STATUS ? candidate : 'ERR_INTERNAL';
  return jsonResponse(
    { data: null, error: { code } },
    ERROR_STATUS[code] ?? 500,
  );
}

export function assertMethod(
  request: Request,
  allowedMethods: readonly string[],
): Response | null {
  if (allowedMethods.includes(request.method)) return null;
  return errorResponse(new Error('ERR_METHOD_NOT_ALLOWED'));
}

export async function readJson(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    throw new Error('ERR_REQUEST_JSON_INVALID');
  }
}
