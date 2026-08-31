-- ============================================================================
-- Function: admin.refresh_route_search_options
-- Purpose: Build a pre-computed route-search projection from direct routes (0-stop)
--          and connecting routes (1-stop via dynamic hubs).
-- Responsibilities: Materialize candidate publication using dedicated pure calculation functions.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.refresh_route_search_options(p_publication_version_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
VOLATILE
SET search_path = ''
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.publication_versions AS version
    WHERE version.id = p_publication_version_id
      AND version.status = 'building'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_PUBLICATION_VERSION_INVALID';
  END IF;

  DELETE FROM public.flight_route_options WHERE publication_version_id = p_publication_version_id;

  -- 1. Insert 0-Stop Direct Non-Stop Routes
  INSERT INTO public.flight_route_options (
    id, publication_version_id,
    origin_city_id, origin_city_slug, origin_country_code,
    destination_city_id, destination_city_slug, destination_country_code,
    origin_airport_id, origin_airport_iata,
    destination_airport_id, destination_airport_iata,
    stops, layover_airport_ids, layover_airports,
    operating_airlines, flight_numbers, flight_durations_minutes,
    total_duration_minutes, total_distance_km, days_of_week,
    route_type, confidence_score, route_path
  )
  SELECT
    gen_random_uuid(), p_publication_version_id,
    origin_city.id, origin_city.slug, origin_country.iso2,
    destination_city.id, destination_city.slug, destination_country.iso2,
    origin_airport.id, origin_airport.iata,
    destination_airport.id, destination_airport.iata,
    0, '{}'::UUID[], '{}'::TEXT[],
    ARRAY[r.airline_iata], r.flight_numbers, ARRAY[r.flight_duration_minutes],
    r.flight_duration_minutes,
    COALESCE(
      NULLIF(r.distance_km, 0),
      admin.calculate_haversine_distance_km(origin_airport.latitude, origin_airport.longitude, destination_airport.latitude, destination_airport.longitude)
    ),
    admin.calculate_route_schedule_intersection(r.days_of_week, NULL),
    admin.classify_route_connection_type(r.airline_iata, NULL),
    1.000,
    COALESCE(registry.canonical_path, '/flights/' || origin_city.slug || '-to-' || destination_city.slug)
  FROM public.direct_flight_routes r
  JOIN public.airports origin_airport ON origin_airport.id = r.origin_airport_id
  JOIN public.cities origin_city ON origin_city.id = origin_airport.city_id
  JOIN public.countries origin_country ON origin_country.id = origin_city.country_id
  JOIN public.airports destination_airport ON destination_airport.id = r.destination_airport_id
  JOIN public.cities destination_city ON destination_city.id = destination_airport.city_id
  JOIN public.countries destination_country ON destination_country.id = destination_city.country_id
  LEFT JOIN public.route_pages page
    ON page.origin_city_id = origin_city.id
   AND page.destination_city_id = destination_city.id
   AND page.locale = 'en-GB'
  LEFT JOIN public.pseo_pages registry ON registry.id = page.pseo_page_id AND registry.status <> 'archived'
  WHERE r.is_active = TRUE
    AND origin_airport.status = 'active'
    AND destination_airport.status = 'active'
    AND origin_city.id <> destination_city.id;

  -- 2. Insert 1-Stop Connecting Routes via Dynamic Hubs
  INSERT INTO public.flight_route_options (
    id, publication_version_id,
    origin_city_id, origin_city_slug, origin_country_code,
    destination_city_id, destination_city_slug, destination_country_code,
    origin_airport_id, origin_airport_iata,
    destination_airport_id, destination_airport_iata,
    stops, layover_airport_ids, layover_airports,
    operating_airlines, flight_numbers, flight_durations_minutes,
    total_duration_minutes, total_distance_km, days_of_week,
    route_type, confidence_score, route_path
  )
  SELECT
    gen_random_uuid(), p_publication_version_id,
    origin_city.id, origin_city.slug, origin_country.iso2,
    destination_city.id, destination_city.slug, destination_country.iso2,
    origin_airport.id, origin_airport.iata,
    destination_airport.id, destination_airport.iata,
    1, ARRAY[hub_airport.id]::UUID[], ARRAY[r1.destination_iata]::TEXT[],
    ARRAY[r1.airline_iata, r2.airline_iata],
    r1.flight_numbers || r2.flight_numbers,
    ARRAY[r1.flight_duration_minutes, r2.flight_duration_minutes],
    admin.calculate_connecting_duration_minutes(r1.flight_duration_minutes, r2.flight_duration_minutes, hub_airport.min_transit_minutes),
    (r1.distance_km + r2.distance_km),
    admin.calculate_route_schedule_intersection(r1.days_of_week, r2.days_of_week),
    admin.classify_route_connection_type(r1.airline_iata, r2.airline_iata),
    0.950,
    COALESCE(registry.canonical_path, '/flights/' || origin_city.slug || '-to-' || destination_city.slug)
  FROM public.direct_flight_routes r1
  JOIN public.airports hub_airport ON hub_airport.id = r1.destination_airport_id AND hub_airport.is_hub = TRUE
  JOIN public.direct_flight_routes r2 ON r2.origin_airport_id = hub_airport.id
  JOIN public.airports origin_airport ON origin_airport.id = r1.origin_airport_id
  JOIN public.cities origin_city ON origin_city.id = origin_airport.city_id
  JOIN public.countries origin_country ON origin_country.id = origin_city.country_id
  JOIN public.airports destination_airport ON destination_airport.id = r2.destination_airport_id
  JOIN public.cities destination_city ON destination_city.id = destination_airport.city_id
  JOIN public.countries destination_country ON destination_country.id = destination_city.country_id
  LEFT JOIN public.route_pages page
    ON page.origin_city_id = origin_city.id
   AND page.destination_city_id = destination_city.id
   AND page.locale = 'en-GB'
  LEFT JOIN public.pseo_pages registry ON registry.id = page.pseo_page_id AND registry.status <> 'archived'
  WHERE r1.is_active = TRUE
    AND r2.is_active = TRUE
    AND origin_airport.status = 'active'
    AND destination_airport.status = 'active'
    AND origin_city.id <> destination_city.id
    AND r1.origin_airport_id <> r2.destination_airport_id;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION admin.refresh_route_search_options(UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.refresh_route_search_options(UUID) TO service_role;
