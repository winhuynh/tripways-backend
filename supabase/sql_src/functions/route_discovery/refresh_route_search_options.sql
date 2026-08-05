-- ============================================================================
-- Function: private.refresh_route_search_options
-- Purpose: Rebuild the shared searchable route projection for one candidate version.
-- Responsibilities: Resolve identities, ordered codes, canonical paths, and display-safe prices.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.refresh_route_search_options(p_publication_version_id UUID)
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
    FROM public.publication_versions version
    WHERE version.id = p_publication_version_id
      AND version.status = 'building'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_PUBLICATION_VERSION_INVALID';
  END IF;

  DELETE FROM public.route_search_options
  WHERE publication_version_id = p_publication_version_id;

  INSERT INTO public.route_search_options (
    id,
    publication_version_id,
    origin_city_id,
    origin_city_slug,
    origin_country_code,
    origin_region_code,
    destination_city_id,
    destination_city_slug,
    destination_country_code,
    destination_region_code,
    is_international,
    origin_airport_id,
    origin_airport_iata,
    destination_airport_id,
    destination_airport_iata,
    stop_count,
    connection_airport_ids,
    connection_airport_iatas,
    operating_airline_ids,
    operating_airline_iatas,
    departure_local_time,
    departure_time_bucket,
    arrival_local_time,
    arrival_day_offset,
    days_of_week,
    valid_from,
    valid_to,
    total_flight_minutes,
    layover_minutes,
    maximum_layover_minutes,
    total_duration_minutes,
    confidence_score,
    route_path,
    price_state,
    price_trip_type,
    price_min,
    price_max,
    currency_code,
    price_valid_until
  )
  SELECT
    option.id,
    p_publication_version_id,
    origin_city.id,
    origin_city.slug,
    origin_country.iso2,
    origin_country.region,
    destination_city.id,
    destination_city.slug,
    destination_country.iso2,
    destination_country.region,
    origin_country.id <> destination_country.id,
    origin_airport.id,
    origin_airport.iata,
    destination_airport.id,
    destination_airport.iata,
    option.stop_count,
    option.connection_airport_ids,
    ARRAY(
      SELECT airport.iata
      FROM unnest(option.connection_airport_ids) WITH ORDINALITY item(id, position)
      JOIN public.airports airport
        ON airport.id = item.id
      ORDER BY item.position
    ),
    option.operating_airline_ids,
    ARRAY(
      SELECT airline.iata
      FROM unnest(option.operating_airline_ids) WITH ORDINALITY item(id, position)
      JOIN public.airlines airline
        ON airline.id = item.id
      ORDER BY item.position
    ),
    option.departure_local_time,
    CASE
      WHEN option.departure_local_time < TIME '06:00' THEN 'early_morning'
      WHEN option.departure_local_time < TIME '12:00' THEN 'morning'
      WHEN option.departure_local_time < TIME '18:00' THEN 'afternoon'
      ELSE 'evening'
    END,
    option.arrival_local_time,
    option.arrival_day_offset,
    option.days_of_week,
    option.valid_from,
    option.valid_to,
    option.total_flight_minutes,
    option.layover_minutes,
    COALESCE((SELECT max(minutes) FROM unnest(option.layover_minutes_by_connection) minutes), 0),
    option.total_duration_minutes,
    option.confidence_score,
    format('/flights/%s-to-%s', origin_city.slug, destination_city.slug),
    COALESCE(price.state, 'missing'),
    CASE WHEN price.state = 'available' THEN 'one_way' ELSE NULL END,
    price.price_min,
    price.price_max,
    price.currency_code,
    price.valid_until
  FROM public.route_options option
  JOIN public.airports origin_airport
    ON origin_airport.id = option.origin_airport_id
  JOIN public.cities origin_city
    ON origin_city.id = origin_airport.city_id
  JOIN public.countries origin_country
    ON origin_country.id = origin_city.country_id
  JOIN public.airports destination_airport
    ON destination_airport.id = option.destination_airport_id
  JOIN public.cities destination_city
    ON destination_city.id = destination_airport.city_id
  JOIN public.countries destination_country
    ON destination_country.id = destination_city.country_id
  LEFT JOIN LATERAL (
    SELECT
      'available'::TEXT AS state,
      estimate.price_min,
      estimate.price_max,
      estimate.currency_code,
      estimate.valid_until
    FROM public.route_price_estimates estimate
    JOIN admin.data_sources source
      ON source.id = estimate.source_id
    WHERE estimate.origin_city_id = origin_city.id
      AND estimate.destination_city_id = destination_city.id
      AND estimate.trip_type = 'one_way'
      AND estimate.status = 'published'
      AND estimate.valid_until > now()
      AND source.production_display_allowed = TRUE
      AND source.derived_data_allowed = TRUE
      AND (
        source.rights_effective_at IS NULL
        OR now() BETWEEN source.rights_effective_at AND source.rights_expires_at
      )
    ORDER BY
      estimate.confidence_score DESC,
      estimate.last_verified_at DESC,
      estimate.id
    LIMIT 1
  ) price ON TRUE;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION private.refresh_route_search_options(UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.refresh_route_search_options(UUID) TO service_role;
