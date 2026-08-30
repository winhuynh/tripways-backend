export type EdgeLogLevel = 'info' | 'warn' | 'error';

export type EdgeLogContext = {
  action?: string | null;
  status?: string | null;
  requestId?: string | null;
  clientRequestId?: string | null;
  edgeFunction?: string | null;
  featureArea?: string | null;
  errorCode?: string | null;
  durationMs?: number | null;
  path?: string | null;
  method?: string | null;
  userId?: string | null;
  [key: string]: unknown;
};

type ErrorLike = {
  code?: unknown;
  message?: unknown;
  name?: unknown;
  details?: unknown;
  hint?: unknown;
  stack?: unknown;
};

const SENSITIVE_KEY_PATTERNS = [
  'token',
  'authorization',
  'apikey',
  'api_key',
  'secret',
  'password',
  'jwt',
  'cookie',
  'raw_payload',
  'bearer',
];

/**
 * Extracts or generates a unique request correlation ID from HTTP headers.
 */
export function extractRequestId(request?: Request | null): string {
  if (!request) return crypto.randomUUID();
  const candidate = request.headers.get('x-request-id') ||
    request.headers.get('x-correlation-id') ||
    request.headers.get('client-request-id');
  if (candidate && candidate.trim().length > 0) {
    return candidate.trim().slice(0, 128);
  }
  return crypto.randomUUID();
}

/**
 * Redacts sensitive fields from context maps or JSON-compatible objects.
 */
export function sanitizeLogValue(value: unknown, depth = 0): unknown {
  if (depth > 5) return '[max_depth_exceeded]';
  if (value === null || value === undefined) return value;

  if (typeof value === 'string') {
    if (value.length > 500) {
      return `${value.slice(0, 500)}...[truncated]`;
    }
    return value;
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) => sanitizeLogValue(item, depth + 1));
  }

  if (typeof value === 'object') {
    const sanitized: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (isSensitiveKey(k)) {
        sanitized[k] = '[redacted]';
      } else {
        sanitized[k] = sanitizeLogValue(v, depth + 1);
      }
    }
    return sanitized;
  }

  return String(value);
}

function isSensitiveKey(key: string): boolean {
  const normalized = key.toLowerCase().replace(/[-_]/g, '');
  return SENSITIVE_KEY_PATTERNS.some((pattern) =>
    normalized.includes(pattern.replace(/[-_]/g, ''))
  );
}

/**
 * Safely extracts error properties and Postgres error hints without crashing.
 */
export function safeExtractError(
  error: unknown,
  fallbackCode?: string | null,
): {
  errorCode: string;
  errorName: string;
  errorMessage: string;
  errorStack?: string;
  dbDetails?: Record<string, unknown>;
} {
  const errorLike = readErrorLike(error);
  const rawMessage = typeof errorLike?.message === 'string'
    ? errorLike.message
    : String(error ?? '');
  const rawCode = typeof errorLike?.code === 'string' ? errorLike.code : null;

  const normalizedCode = normalizeErrorCode(rawCode) ||
    normalizeErrorCode(rawMessage) ||
    normalizeErrorCode(fallbackCode) ||
    'ERR_INTERNAL';

  const errorName = typeof errorLike?.name === 'string' && errorLike.name.trim().length > 0
    ? errorLike.name.trim()
    : 'Error';

  const errorStack = typeof errorLike?.stack === 'string' ? errorLike.stack : undefined;

  const dbDetails: Record<string, unknown> = {};
  if (errorLike?.details && typeof errorLike.details === 'string') {
    dbDetails.details = errorLike.details;
  }
  if (errorLike?.hint && typeof errorLike.hint === 'string') {
    dbDetails.hint = errorLike.hint;
  }

  return {
    errorCode: normalizedCode,
    errorName,
    errorMessage: rawMessage.slice(0, 1000),
    ...(errorStack ? { errorStack } : {}),
    ...(Object.keys(dbDetails).length > 0 ? { dbDetails } : {}),
  };
}

function readErrorLike(error: unknown): ErrorLike | null {
  if (error instanceof Error) {
    const errorRecord = error as unknown as Record<string, unknown>;
    return {
      name: error.name,
      message: error.message,
      stack: error.stack,
      ...(errorRecord.code ? { code: errorRecord.code } : {}),
      ...(errorRecord.details ? { details: errorRecord.details } : {}),
      ...(errorRecord.hint ? { hint: errorRecord.hint } : {}),
    };
  }
  if (typeof error === 'object' && error !== null && !Array.isArray(error)) {
    return error as ErrorLike;
  }
  if (typeof error === 'string') {
    return { message: error };
  }
  return null;
}

function normalizeErrorCode(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (/^ERR_[A-Z0-9_]+$/.test(trimmed)) return trimmed;
  if (/^[A-Z][A-Z0-9_]{2,}$/.test(trimmed)) return trimmed;
  return null;
}

function emitStructuredLog(
  level: EdgeLogLevel,
  eventName: string,
  payload: Record<string, unknown>,
): void {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    event_name: eventName,
    ...payload,
  };
  const line = JSON.stringify(logEntry);
  if (level === 'error') {
    console.error(line);
  } else if (level === 'warn') {
    console.warn(line);
  } else {
    console.info(line);
  }
}

/**
 * Structured info logger for Edge Functions.
 */
export function logEdgeInfo(
  eventName: string,
  context: EdgeLogContext = {},
): void {
  const sanitized = sanitizeLogValue(context) as Record<string, unknown>;
  emitStructuredLog('info', eventName, sanitized);
}

/**
 * Structured warn logger for Edge Functions.
 */
export function logEdgeWarn(
  eventName: string,
  errorOrContext?: unknown,
  context: EdgeLogContext = {},
): void {
  let payload: Record<string, unknown> = {};
  if (
    errorOrContext instanceof Error ||
    (typeof errorOrContext === 'object' && errorOrContext !== null && 'message' in errorOrContext)
  ) {
    const errorFields = safeExtractError(errorOrContext, context.errorCode);
    payload = {
      ...((sanitizeLogValue(context) as Record<string, unknown>) || {}),
      error_code: errorFields.errorCode,
      error_name: errorFields.errorName,
      error_message: errorFields.errorMessage,
      ...(errorFields.dbDetails ? { db_details: errorFields.dbDetails } : {}),
    };
  } else if (typeof errorOrContext === 'object' && errorOrContext !== null) {
    payload = sanitizeLogValue({ ...errorOrContext, ...context }) as Record<string, unknown>;
  } else {
    payload = sanitizeLogValue(context) as Record<string, unknown>;
  }
  emitStructuredLog('warn', eventName, payload);
}

/**
 * Structured error logger for Edge Functions.
 */
export function logEdgeError(
  eventName: string,
  error: unknown,
  context: EdgeLogContext = {},
): void {
  const errorFields = safeExtractError(error, context.errorCode);
  const payload: Record<string, unknown> = {
    ...((sanitizeLogValue(context) as Record<string, unknown>) || {}),
    error_code: errorFields.errorCode,
    error_name: errorFields.errorName,
    error_message: errorFields.errorMessage,
    ...(errorFields.errorStack ? { error_stack: errorFields.errorStack } : {}),
    ...(errorFields.dbDetails ? { db_details: errorFields.dbDetails } : {}),
  };

  emitStructuredLog('error', eventName, payload);
}
