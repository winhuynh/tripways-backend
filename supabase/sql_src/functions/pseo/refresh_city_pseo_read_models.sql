-- ============================================================================
-- Function: public.refresh_city_pseo_read_models
-- Feature: Interactive pSEO
-- Purpose: Rebuild filterable city direct routes, destination summaries, and page facts.
-- Responsibilities: Apply route eligibility once, publish one data version, and preserve freshness.
-- Notes: The projection is rebuildable and never replaces normalized route or schedule truth.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.refresh_city_pseo_read_models()
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Version and result
  ------------------------------------------------------------------
  v_data_version UUID := gen_random_uuid();
  v_route_count INTEGER;
  v_destination_count INTEGER;
  v_page_count INTEGER;
BEGIN
  -- STEP 01: Replace the rebuildable projections with one coherent version.
  DELETE FROM public.city_destination_summaries;
  DELETE FROM public.city_direct_routes;

  INSERT INTO public.city_direct_routes (
    origin_city_id,
    origin_airport_id,
    destination_city_id,
    destination_airport_id,
    destination_country_id,
    operating_airline_id,
    marketing_airline_id,
    flight_route_id,
    service_count,
    frequency_per_week,
    shortest_duration_minutes,
    longest_duration_minutes,
    earliest_departure_time,
    latest_departure_time,
    seasonality,
    seasonal_start,
    seasonal_end,
    confidence_score,
    source_freshness_at,
    data_version
  )
  SELECT
    origin_airport.city_id,
    origin_airport.id,
    destination_airport.city_id,
    destination_airport.id,
    destination_airport.country_id,
    flight_route.operating_airline_id,
    flight_route.marketing_airline_id,
    flight_route.id,
    count(DISTINCT flight_service.id)::INTEGER,
    flight_route.frequency_per_week,
    min(flight_service.duration_minutes),
    max(flight_service.duration_minutes),
    min(flight_service.departure_local_time),
    max(flight_service.departure_local_time),
    flight_route.seasonality,
    flight_route.seasonal_start,
    flight_route.seasonal_end,
    least(
      flight_route.confidence_score,
      min(flight_service.confidence_score)
    ),
    min(
      least(
        flight_route.last_verified_at,
        flight_service.last_verified_at,
        origin_airport.last_verified_at,
        destination_airport.last_verified_at,
        operating_airline.last_verified_at
      )
    ),
    v_data_version
  FROM public.flight_routes flight_route
  JOIN public.airports origin_airport
    ON origin_airport.id = flight_route.origin_airport_id
  JOIN public.airports destination_airport
    ON destination_airport.id = flight_route.destination_airport_id
  JOIN public.airlines operating_airline
    ON operating_airline.id = flight_route.operating_airline_id
  JOIN public.flight_services flight_service
    ON flight_service.flight_route_id = flight_route.id
  WHERE origin_airport.city_id IS NOT NULL
    AND destination_airport.city_id IS NOT NULL
    AND origin_airport.city_id <> destination_airport.city_id
    AND origin_airport.status = 'active'
    AND destination_airport.status = 'active'
    AND operating_airline.status = 'active'
    AND flight_route.status IN ('verified_active', 'likely_active', 'seasonal')
    AND flight_service.valid_to >= CURRENT_DATE
    AND flight_service.valid_from <= CURRENT_DATE
  GROUP BY
    origin_airport.city_id,
    origin_airport.id,
    destination_airport.city_id,
    destination_airport.id,
    destination_airport.country_id,
    flight_route.operating_airline_id,
    flight_route.marketing_airline_id,
    flight_route.id,
    flight_route.frequency_per_week,
    flight_route.seasonality,
    flight_route.seasonal_start,
    flight_route.seasonal_end,
    flight_route.confidence_score;

  GET DIAGNOSTICS v_route_count = ROW_COUNT;

  -- STEP 02: Aggregate stable default destination cards from the same version.
  INSERT INTO public.city_destination_summaries (
    origin_city_id,
    destination_city_id,
    destination_country_id,
    origin_airport_count,
    destination_airport_count,
    airline_count,
    direct_route_count,
    frequency_per_week,
    shortest_duration_minutes,
    longest_duration_minutes,
    distance_km,
    seasonality,
    confidence_score,
    ranking_score,
    source_freshness_at,
    data_version
  )
  SELECT
    city_route.origin_city_id,
    city_route.destination_city_id,
    city_route.destination_country_id,
    count(DISTINCT city_route.origin_airport_id)::INTEGER,
    count(DISTINCT city_route.destination_airport_id)::INTEGER,
    count(DISTINCT city_route.operating_airline_id)::INTEGER,
    count(*)::INTEGER,
    CASE
      WHEN count(city_route.frequency_per_week) = 0 THEN NULL
      ELSE sum(city_route.frequency_per_week)
    END,
    min(city_route.shortest_duration_minutes),
    max(city_route.longest_duration_minutes),
    NULL,
    CASE
      WHEN count(DISTINCT city_route.seasonality) = 1 THEN min(city_route.seasonality)
      ELSE 'mixed'
    END,
    min(city_route.confidence_score),
    (
      COALESCE(sum(city_route.frequency_per_week), 0) * 10000
      + count(*) * 100
      + min(city_route.confidence_score) * 10
      - min(city_route.shortest_duration_minutes)
    ),
    min(city_route.source_freshness_at),
    v_data_version
  FROM public.city_direct_routes city_route
  WHERE city_route.data_version = v_data_version
  GROUP BY
    city_route.origin_city_id,
    city_route.destination_city_id,
    city_route.destination_country_id;

  GET DIAGNOSTICS v_destination_count = ROW_COUNT;

  -- STEP 03: Refresh page facts without changing reviewed editorial content.
  WITH page_facts AS (
    SELECT
      city_page.id AS city_page_id,
      count(DISTINCT airport.id)
        FILTER (WHERE airport.status = 'active')::INTEGER AS airport_count,
      count(DISTINCT destination.destination_city_id)::INTEGER AS direct_destination_count,
      count(DISTINCT destination.destination_country_id)::INTEGER AS direct_country_count,
      count(DISTINCT city_route.operating_airline_id)::INTEGER AS airline_count,
      min(destination.shortest_duration_minutes) AS shortest_route_minutes,
      max(destination.longest_duration_minutes) AS longest_route_minutes,
      min(destination.source_freshness_at) AS source_freshness_at
    FROM public.city_pages city_page
    LEFT JOIN public.airports airport
      ON airport.city_id = city_page.city_id
    LEFT JOIN public.city_destination_summaries destination
      ON destination.origin_city_id = city_page.city_id
      AND destination.data_version = v_data_version
    LEFT JOIN public.city_direct_routes city_route
      ON city_route.origin_city_id = city_page.city_id
      AND city_route.data_version = v_data_version
    GROUP BY city_page.id
  )
  UPDATE public.city_pages city_page
  SET
    airport_count = page_facts.airport_count,
    direct_destination_count = page_facts.direct_destination_count,
    direct_country_count = page_facts.direct_country_count,
    airline_count = page_facts.airline_count,
    shortest_route_minutes = page_facts.shortest_route_minutes,
    longest_route_minutes = page_facts.longest_route_minutes,
    source_freshness_at = page_facts.source_freshness_at,
    data_version = v_data_version,
    generated_at = now(),
    updated_at = now()
  FROM page_facts
  WHERE city_page.id = page_facts.city_page_id;

  GET DIAGNOSTICS v_page_count = ROW_COUNT;

  -- STEP 04: Derive indexability from content state, route utility, and source rights.
  WITH page_eligibility AS (
    SELECT
      city_page.id AS city_page_id,
      EXISTS (
        SELECT 1
        FROM public.city_direct_routes city_route
        JOIN public.flight_routes flight_route
          ON flight_route.id = city_route.flight_route_id
        JOIN admin.data_sources data_source
          ON data_source.id = flight_route.source_id
        WHERE city_route.origin_city_id = city_page.city_id
          AND city_route.data_version = v_data_version
          AND data_source.environment_scope = 'development'
      ) AS has_development_source,
      EXISTS (
        SELECT 1
        FROM public.city_direct_routes city_route
        JOIN public.flight_routes flight_route
          ON flight_route.id = city_route.flight_route_id
        JOIN admin.data_sources data_source
          ON data_source.id = flight_route.source_id
        WHERE city_route.origin_city_id = city_page.city_id
          AND city_route.data_version = v_data_version
          AND (
            data_source.production_allowed = FALSE
            OR data_source.seo_allowed = FALSE
            OR data_source.derived_data_allowed = FALSE
          )
      ) AS has_disallowed_source
    FROM public.city_pages city_page
  )
  UPDATE public.city_pages city_page
  SET
    is_indexable = CASE
      WHEN page_eligibility.has_development_source THEN FALSE
      WHEN city_page.status <> 'published' THEN FALSE
      WHEN city_page.direct_destination_count = 0 THEN FALSE
      WHEN city_page.content_reviewed_at IS NULL THEN FALSE
      WHEN page_eligibility.has_disallowed_source THEN FALSE
      ELSE TRUE
    END,
    noindex_reason = CASE
      WHEN page_eligibility.has_development_source THEN 'development_fixture'
      WHEN city_page.status <> 'published' THEN 'not_published'
      WHEN city_page.direct_destination_count = 0 THEN 'no_direct_routes'
      WHEN city_page.content_reviewed_at IS NULL THEN 'content_not_reviewed'
      WHEN page_eligibility.has_disallowed_source THEN 'source_not_seo_eligible'
      ELSE NULL
    END,
    updated_at = now()
  FROM page_eligibility
  WHERE city_page.id = page_eligibility.city_page_id;

  UPDATE public.pseo_pages pseo_page
  SET
    status = city_page.status,
    is_indexable = city_page.is_indexable,
    noindex_reason = city_page.noindex_reason,
    data_version = city_page.data_version,
    source_freshness_at = city_page.source_freshness_at,
    generated_at = city_page.generated_at
  FROM public.city_pages city_page
  WHERE city_page.pseo_page_id = pseo_page.id;

  UPDATE public.pseo_internal_links
  SET
    data_version = v_data_version,
    generated_at = now();

  -- STEP 05: Return deterministic refresh evidence.
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'data_version', v_data_version,
      'direct_routes', v_route_count,
      'destination_summaries', v_destination_count,
      'city_pages', v_page_count
    ),
    'meta', jsonb_build_object(
      'generated_at', now()
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_city_pseo_read_models()
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_city_pseo_read_models() TO service_role;
