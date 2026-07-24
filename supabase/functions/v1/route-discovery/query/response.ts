export type RouteSearchInternalEnvelope = {
  data: unknown[];
  meta: {
    total: number;
    limit: number;
    offset: number;
    facets: {
      stops: Array<{ value: number; count: number }>;
      airlines: Array<{ value: string; count: number }>;
    };
  };
  error: null;
};

export type RouteDiscoverySuccessResponse = {
  status: 'success';
  data: {
    routes: unknown[];
    pagination: { total: number; limit: number; offset: number };
    facets: RouteSearchInternalEnvelope['meta']['facets'];
  };
  error: null;
};

export function mapRouteSearchResponse(value: unknown): RouteDiscoverySuccessResponse {
  if (!isRecord(value) || value.error !== null || !Array.isArray(value.data)) {
    contractError();
  }
  if (!value.data.every(isRoute)) contractError();

  const meta = value.meta;
  if (
    !isRecord(meta) || !isNonNegativeInteger(meta.total) ||
    !isNonNegativeInteger(meta.limit) || !isNonNegativeInteger(meta.offset) ||
    !isRecord(meta.facets)
  ) {
    contractError();
  }

  const stops = parseFacets(meta.facets.stops, 'number');
  const airlines = parseFacets(meta.facets.airlines, 'string');

  return {
    status: 'success',
    data: {
      routes: value.data,
      pagination: { total: meta.total, limit: meta.limit, offset: meta.offset },
      facets: {
        stops: stops as Array<{ value: number; count: number }>,
        airlines: airlines as Array<{ value: string; count: number }>,
      },
    },
    error: null,
  };
}

function parseFacets(
  value: unknown,
  valueType: 'number' | 'string',
): Array<{ value: number | string; count: number }> {
  if (!Array.isArray(value)) contractError();
  return value.map((item) => {
    if (!isRecord(item) || typeof item.value !== valueType || !isNonNegativeInteger(item.count)) {
      contractError();
    }
    return { value: item.value as number | string, count: item.count };
  });
}

function isRoute(value: unknown): boolean {
  if (!isRecord(value)) return false;
  return typeof value.id === 'string' &&
    typeof value.from === 'string' &&
    typeof value.to === 'string' &&
    typeof value.stops === 'number' &&
    isStringArray(value.connection_airports) &&
    isStringArray(value.operating_airlines) &&
    typeof value.total_flight_minutes === 'number' &&
    (typeof value.layover_minutes === 'number' || value.layover_minutes === null) &&
    typeof value.total_duration_minutes === 'number' &&
    typeof value.departure_local_time === 'string' &&
    typeof value.arrival_local_time === 'string' &&
    typeof value.arrival_day_offset === 'number' &&
    typeof value.valid_from === 'string' &&
    typeof value.valid_to === 'string' &&
    Array.isArray(value.days_of_week) &&
    value.days_of_week.every((item) => typeof item === 'number') &&
    typeof value.confidence_score === 'number' &&
    typeof value.data_version === 'string';
}

function isStringArray(value: unknown): boolean {
  return Array.isArray(value) && value.every((item) => typeof item === 'string');
}

function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0;
}

function contractError(): never {
  throw new Error('ERR_ROUTE_DISCOVERY_CONTRACT');
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
