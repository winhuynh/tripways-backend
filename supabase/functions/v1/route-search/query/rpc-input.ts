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
  return {
    scope: input.scope,
    filters: {
      max_stops: input.filters.maxStops,
      airlines: input.filters.airlines,
      connection_airports: input.filters.connectionAirports,
      departure_airports: input.filters.departureAirports,
      destination_countries: input.filters.destinationCountries,
      destination_regions: input.filters.destinationRegions,
      counterpart_query: input.filters.counterpartQuery,
      counterpart_countries: input.filters.counterpartCountries,
      counterpart_regions: input.filters.counterpartRegions,
      departure_time_buckets: input.filters.departureTimeBuckets,
      route_type: input.filters.routeType,
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
