import type { RouteSearchRequest } from '@shared/contracts/route-filters.ts';

export type RouteSearchRpcInput = {
  scope: RouteSearchRequest['scope'];
  filters: Partial<{
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
    days_of_week: number[];
    route_type: RouteSearchRequest['filters']['routeType'];
    max_duration_minutes: number | null;
    max_layover_minutes: number | null;
    cabin: RouteSearchRequest['filters']['cabin'];
    max_amount: number | null;
    currency: string | null;
  }>;
  page_size: number;
  after: string | null;
};

export function toRouteSearchRpcInput(input: RouteSearchRequest): RouteSearchRpcInput {
  const filters: RouteSearchRpcInput['filters'] = {
    max_stops: input.filters.maxStops,
    route_type: input.filters.routeType,
    cabin: input.filters.cabin,
  };
  if (input.filters.airlines.length > 0) filters.airlines = input.filters.airlines;
  if (input.filters.connectionAirports.length > 0) {
    filters.connection_airports = input.filters.connectionAirports;
  }
  if (input.filters.departureAirports.length > 0) {
    filters.departure_airports = input.filters.departureAirports;
  }
  if (input.filters.destinationCountries.length > 0) {
    filters.destination_countries = input.filters.destinationCountries;
  }
  if (input.filters.destinationRegions.length > 0) {
    filters.destination_regions = input.filters.destinationRegions;
  }
  if (input.filters.counterpartQuery !== null) {
    filters.counterpart_query = input.filters.counterpartQuery;
  }
  if (input.filters.counterpartCountries.length > 0) {
    filters.counterpart_countries = input.filters.counterpartCountries;
  }
  if (input.filters.counterpartRegions.length > 0) {
    filters.counterpart_regions = input.filters.counterpartRegions;
  }
  if (input.filters.departureTimeBuckets.length > 0) {
    filters.departure_time_buckets = input.filters.departureTimeBuckets;
  }
  if (input.filters.daysOfWeek.length > 0) filters.days_of_week = input.filters.daysOfWeek;
  if (input.filters.maxDurationMinutes !== null) {
    filters.max_duration_minutes = input.filters.maxDurationMinutes;
  }
  if (input.filters.maxLayoverMinutes !== null) {
    filters.max_layover_minutes = input.filters.maxLayoverMinutes;
  }
  if (input.filters.priceMax !== null && input.filters.currency !== null) {
    filters.max_amount = input.filters.priceMax;
    filters.currency = input.filters.currency;
  }
  return {
    scope: input.scope,
    filters,
    page_size: input.pageSize,
    after: input.after,
  };
}
