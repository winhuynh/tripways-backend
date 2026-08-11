-- ============================================================================
-- Function: private.refresh_route_search_options
-- Purpose: Build the only route projection consumed by search and every pSEO page.
-- Responsibilities: Apply one eligibility policy, expand bounded connections, and bind one publication.
-- Notes: Normalized routes/services remain truth; this table is a disposable publication projection.
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
    FROM public.publication_versions AS version
    WHERE version.id = p_publication_version_id
      AND version.status = 'building'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_PUBLICATION_VERSION_INVALID';
  END IF;

  DELETE FROM public.route_search_options
  WHERE publication_version_id = p_publication_version_id;

  WITH RECURSIVE route_paths AS (
    SELECT
      ARRAY[service.id]::UUID[] AS service_ids,
      ARRAY[route.origin_airport_id, route.destination_airport_id]::UUID[] AS airport_path,
      route.origin_airport_id,
      route.destination_airport_id,
      '{}'::UUID[] AS connection_airport_ids,
      ARRAY[service.operating_airline_id]::UUID[] AS operating_airline_ids,
      service.departure_local_time,
      service.arrival_local_time,
      service.arrival_day_offset::INTEGER AS arrival_day_offset,
      service.valid_from,
      service.valid_to,
      service.days_of_week,
      service.duration_minutes AS total_flight_minutes,
      0 AS layover_minutes,
      '{}'::INTEGER[] AS layover_minutes_by_connection,
      service.duration_minutes AS total_duration_minutes,
      LEAST(route.confidence_score, service.confidence_score)::NUMERIC(4,3) AS confidence_score
    FROM public.flight_services AS service
    JOIN public.flight_routes AS route
      ON route.id = service.flight_route_id
    JOIN public.airports AS origin_airport
      ON origin_airport.id = route.origin_airport_id
    JOIN public.airports AS destination_airport
      ON destination_airport.id = route.destination_airport_id
    JOIN public.airlines AS airline
      ON airline.id = service.operating_airline_id
    JOIN admin.data_sources AS source
      ON source.id = route.source_id
    WHERE route.status IN ('verified_active', 'likely_active', 'seasonal')
      AND service.valid_from <= CURRENT_DATE
      AND service.valid_to >= CURRENT_DATE
      AND origin_airport.status = 'active'
      AND destination_airport.status = 'active'
      AND origin_airport.city_id IS NOT NULL
      AND destination_airport.city_id IS NOT NULL
      AND origin_airport.city_id <> destination_airport.city_id
      AND airline.status = 'active'
      AND (source.derived_data_allowed OR source.source_type = 'development_fixture')

    UNION ALL

    SELECT
      path.service_ids || next_service.id,
      path.airport_path || next_route.destination_airport_id,
      path.origin_airport_id,
      next_route.destination_airport_id,
      path.connection_airport_ids || next_route.origin_airport_id,
      path.operating_airline_ids || next_service.operating_airline_id,
      path.departure_local_time,
      next_service.arrival_local_time,
      path.arrival_day_offset
        + CASE WHEN next_service.departure_local_time <= path.arrival_local_time THEN 1 ELSE 0 END
        + next_service.arrival_day_offset,
      GREATEST(path.valid_from, next_service.valid_from),
      LEAST(path.valid_to, next_service.valid_to),
      schedule_days.days_of_week,
      path.total_flight_minutes + next_service.duration_minutes,
      path.layover_minutes + connection.layover_minutes,
      path.layover_minutes_by_connection || connection.layover_minutes,
      path.total_duration_minutes + connection.layover_minutes + next_service.duration_minutes,
      LEAST(path.confidence_score, next_route.confidence_score, next_service.confidence_score)::NUMERIC(4,3)
    FROM route_paths AS path
    JOIN public.flight_routes AS next_route
      ON next_route.origin_airport_id = path.destination_airport_id
    JOIN public.flight_services AS next_service
      ON next_service.flight_route_id = next_route.id
    JOIN public.airports AS next_airport
      ON next_airport.id = next_route.destination_airport_id
    JOIN public.airlines AS next_airline
      ON next_airline.id = next_service.operating_airline_id
    JOIN admin.data_sources AS next_source
      ON next_source.id = next_route.source_id
    CROSS JOIN LATERAL (
      SELECT public.calculate_layover_minutes(
        path.arrival_local_time,
        path.arrival_day_offset::SMALLINT,
        next_service.departure_local_time
      ) AS layover_minutes
    ) AS connection
    CROSS JOIN LATERAL (
      SELECT ARRAY(
        SELECT day_value
        FROM unnest(path.days_of_week) AS day_value
        INTERSECT
        SELECT day_value
        FROM unnest(next_service.days_of_week) AS day_value
        ORDER BY day_value
      )::SMALLINT[] AS days_of_week
    ) AS schedule_days
    WHERE cardinality(path.service_ids) < 4
      AND next_route.status IN ('verified_active', 'likely_active', 'seasonal')
      AND next_service.valid_from <= CURRENT_DATE
      AND next_service.valid_to >= CURRENT_DATE
      AND next_airport.status = 'active'
      AND next_airline.status = 'active'
      AND (next_source.derived_data_allowed OR next_source.source_type = 'development_fixture')
      AND NOT (next_route.destination_airport_id = ANY(path.airport_path))
      AND cardinality(schedule_days.days_of_week) > 0
      AND GREATEST(path.valid_from, next_service.valid_from)
        <= LEAST(path.valid_to, next_service.valid_to)
      AND connection.layover_minutes BETWEEN 45 AND 1440
      AND path.total_duration_minutes + connection.layover_minutes + next_service.duration_minutes <= 10080
      AND path.arrival_day_offset
        + CASE WHEN next_service.departure_local_time <= path.arrival_local_time THEN 1 ELSE 0 END
        + next_service.arrival_day_offset <= 7
  ),
  ranked_paths AS (
    SELECT
      path.*,
      row_number() OVER (
        PARTITION BY path.origin_airport_id, path.destination_airport_id, cardinality(path.service_ids)
        ORDER BY path.total_duration_minutes, path.confidence_score DESC, path.service_ids::TEXT
      ) AS candidate_rank
    FROM route_paths AS path
  )
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
    gen_random_uuid(),
    p_publication_version_id,
    origin_city.id,
    origin_page.entity_key,
    origin_country.iso2,
    origin_country.region,
    destination_city.id,
    destination_page.entity_key,
    destination_country.iso2,
    destination_country.region,
    origin_country.id <> destination_country.id,
    origin_airport.id,
    origin_airport.iata,
    destination_airport.id,
    destination_airport.iata,
    (cardinality(path.service_ids) - 1)::SMALLINT,
    path.connection_airport_ids,
    ARRAY(
      SELECT airport.iata
      FROM unnest(path.connection_airport_ids) WITH ORDINALITY AS item(id, position)
      JOIN public.airports AS airport ON airport.id = item.id
      ORDER BY item.position
    ),
    path.operating_airline_ids,
    ARRAY(
      SELECT airline.iata
      FROM unnest(path.operating_airline_ids) WITH ORDINALITY AS item(id, position)
      JOIN public.airlines AS airline ON airline.id = item.id
      ORDER BY item.position
    ),
    path.departure_local_time,
    CASE
      WHEN path.departure_local_time < TIME '06:00' THEN 'early_morning'
      WHEN path.departure_local_time < TIME '12:00' THEN 'morning'
      WHEN path.departure_local_time < TIME '18:00' THEN 'afternoon'
      ELSE 'evening'
    END,
    path.arrival_local_time,
    path.arrival_day_offset::SMALLINT,
    path.days_of_week,
    path.valid_from,
    path.valid_to,
    path.total_flight_minutes,
    path.layover_minutes,
    COALESCE((SELECT max(value) FROM unnest(path.layover_minutes_by_connection) AS value), 0),
    path.total_duration_minutes,
    path.confidence_score,
    route_registry.canonical_path,
    COALESCE(price.state, 'missing'),
    CASE WHEN price.state = 'available' THEN 'one_way' ELSE NULL END,
    price.price_min,
    price.price_max,
    price.currency_code,
    price.valid_until
  FROM ranked_paths AS path
  JOIN public.airports AS origin_airport ON origin_airport.id = path.origin_airport_id
  JOIN public.cities AS origin_city ON origin_city.id = origin_airport.city_id
  JOIN public.countries AS origin_country ON origin_country.id = origin_city.country_id
  JOIN public.airports AS destination_airport ON destination_airport.id = path.destination_airport_id
  JOIN public.cities AS destination_city ON destination_city.id = destination_airport.city_id
  JOIN public.countries AS destination_country ON destination_country.id = destination_city.country_id
  JOIN public.city_pages AS origin_content ON origin_content.city_id = origin_city.id AND origin_content.locale = 'en-GB' AND origin_content.route_direction = 'outbound'
  JOIN public.pseo_pages AS origin_page ON origin_page.id = origin_content.pseo_page_id
  JOIN public.city_pages AS destination_content ON destination_content.city_id = destination_city.id AND destination_content.locale = 'en-GB' AND destination_content.route_direction = 'outbound'
  JOIN public.pseo_pages AS destination_page ON destination_page.id = destination_content.pseo_page_id
  LEFT JOIN public.route_pages AS route_content ON route_content.origin_city_id = origin_city.id AND route_content.destination_city_id = destination_city.id AND route_content.locale = 'en-GB'
  LEFT JOIN public.pseo_pages AS route_registry ON route_registry.id = route_content.pseo_page_id AND route_registry.status <> 'archived'
  LEFT JOIN LATERAL (
    SELECT
      'available'::TEXT AS state,
      estimate.price_min,
      estimate.price_max,
      estimate.currency_code,
      estimate.valid_until
    FROM public.route_price_estimates AS estimate
    JOIN admin.data_sources AS source ON source.id = estimate.source_id
    WHERE estimate.origin_city_id = origin_city.id
      AND estimate.destination_city_id = destination_city.id
      AND estimate.trip_type = 'one_way'
      AND estimate.status = 'published'
      AND estimate.valid_until > now()
      AND source.production_display_allowed
      AND source.derived_data_allowed
    ORDER BY estimate.confidence_score DESC, estimate.last_verified_at DESC, estimate.id
    LIMIT 1
  ) AS price ON TRUE
  WHERE path.candidate_rank <= 200;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION private.refresh_route_search_options(UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.refresh_route_search_options(UUID) TO service_role;
