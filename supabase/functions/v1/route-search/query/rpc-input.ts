import type { RouteSearchRequest } from '@shared/contracts/route-filters.ts';

export type RouteSearchRpcInput = {
  scope: RouteSearchRequest['scope'];
  filters: {
    max_stops: number;
    airlines: string[];
    connection_airports: string[];
    departure_airports: string[];
    destination_countries: string[];
    destination_regions: string[];
    counterpart_query: string | null;
    counterpart_countries: string[];
    counterpart_regions: string[];
    departure_time_buckets: string[];
    route_type: RouteSearchRequest['filters']['routeType'];
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
  const filters: Record<string, unknown> = {};
  if (input.filters.currency) filters.currency = input.filters.currency;
  if (input.filters.priceMax !== null && input.filters.priceMax !== undefined) {
    filters.max_amount = input.filters.priceMax;
  }
  return {
    scope: input.scope,
    filters: filters as RouteSearchRpcInput['filters'],
    page_size: input.pageSize,
  } as RouteSearchRpcInput;
}
