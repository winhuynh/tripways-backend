export type CityPageSuccessResponse = {
  status: 'success';
  data: unknown;
  meta: Record<string, unknown>;
  error: null;
};

export function mapCityPageResponse(value: unknown): CityPageSuccessResponse {
  if (!isRecord(value) || value.error !== null || !isRecord(value.meta) || !('data' in value)) {
    throw new Error('ERR_CITY_PAGE_CONTRACT');
  }

  return {
    status: 'success',
    data: value.data,
    meta: value.meta,
    error: null,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
