import type { RouteSearchRequest } from '@shared/contracts/route-filters.ts';

export type RouteSearchRpcInput = {
  scope: RouteSearchRequest['scope'];
  filters: {
    max_stops: number;
    airlines: string[];
    connection_airports: string[];
    max_duration_minutes: number | null;
    max_layover_minutes: number | null;
    cabin: RouteSearchRequest['filters']['cabin'];
    price_max: number | null;
    currency: string | null;
  };
  page_size: number;
  after: string | null;
};

export function toRouteSearchRpcInput(input: RouteSearchRequest): RouteSearchRpcInput {
  return {
    scope: input.scope,
    filters: {
      max_stops: input.filters.maxStops,
      airlines: input.filters.airlines,
      connection_airports: input.filters.connectionAirports,
      max_duration_minutes: input.filters.maxDurationMinutes,
      max_layover_minutes: input.filters.maxLayoverMinutes,
      cabin: input.filters.cabin,
      price_max: input.filters.priceMax,
      currency: input.filters.currency,
    },
    page_size: input.pageSize,
    after: input.after,
  };
}
