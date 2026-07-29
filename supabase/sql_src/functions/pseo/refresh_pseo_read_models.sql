-- ============================================================================
-- Function: public.refresh_pseo_read_models
-- Feature: Interactive pSEO
-- Purpose: Rebuild filterable city direct routes, destination summaries, and page facts.
-- Responsibilities: Apply route eligibility once, publish one data version, and preserve freshness.
-- Notes: The projection is rebuildable and never replaces normalized route or schedule truth.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.refresh_pseo_read_models()
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
  v_airport_page_count INTEGER;
BEGIN
  -- STEP 01: Replace the rebuildable projections with one coherent version.
  DELETE FROM public.city_destination_summaries;
  DELETE FROM public.pseo_direct_routes;

  INSERT INTO public.pseo_direct_routes (
    origin_city_id,
    origin_airport_id,
    origin_country_id,
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
    origin_airport.country_id,
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
  FROM public.pseo_direct_routes city_route
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
      count(
        DISTINCT CASE
          WHEN city_page.route_direction = 'outbound' THEN city_route.destination_city_id
          ELSE city_route.origin_city_id
        END
      )::INTEGER AS direct_counterpart_city_count,
      count(
        DISTINCT CASE
          WHEN city_page.route_direction = 'outbound' THEN city_route.destination_country_id
          ELSE city_route.origin_country_id
        END
      )::INTEGER AS direct_counterpart_country_count,
      count(DISTINCT city_route.operating_airline_id)::INTEGER AS airline_count,
      min(city_route.shortest_duration_minutes) AS shortest_route_minutes,
      max(city_route.longest_duration_minutes) AS longest_route_minutes,
      min(city_route.source_freshness_at) AS source_freshness_at
    FROM public.city_pages city_page
    LEFT JOIN public.airports airport
      ON airport.city_id = city_page.city_id
    LEFT JOIN public.pseo_direct_routes city_route
      ON city_route.data_version = v_data_version
      AND (
        (
          city_page.route_direction = 'outbound'
          AND city_route.origin_city_id = city_page.city_id
        )
        OR
        (
          city_page.route_direction = 'inbound'
          AND city_route.destination_city_id = city_page.city_id
        )
      )
    GROUP BY city_page.id
  )
  UPDATE public.city_pages city_page
  SET
    airport_count = page_facts.airport_count,
    direct_counterpart_city_count = page_facts.direct_counterpart_city_count,
    direct_counterpart_country_count = page_facts.direct_counterpart_country_count,
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
        FROM public.pseo_direct_routes city_route
        JOIN public.flight_routes flight_route
          ON flight_route.id = city_route.flight_route_id
        JOIN admin.data_sources data_source
          ON data_source.id = flight_route.source_id
        WHERE (
            (
              city_page.route_direction = 'outbound'
              AND city_route.origin_city_id = city_page.city_id
            )
            OR
            (
              city_page.route_direction = 'inbound'
              AND city_route.destination_city_id = city_page.city_id
            )
          )
          AND city_route.data_version = v_data_version
          AND data_source.environment_scope = 'development'
      ) AS has_development_source,
      EXISTS (
        SELECT 1
        FROM public.pseo_direct_routes city_route
        JOIN public.flight_routes flight_route
          ON flight_route.id = city_route.flight_route_id
        JOIN admin.data_sources data_source
          ON data_source.id = flight_route.source_id
        WHERE (
            (
              city_page.route_direction = 'outbound'
              AND city_route.origin_city_id = city_page.city_id
            )
            OR
            (
              city_page.route_direction = 'inbound'
              AND city_route.destination_city_id = city_page.city_id
            )
          )
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
      WHEN city_page.direct_counterpart_city_count = 0 THEN FALSE
      WHEN city_page.content_reviewed_at IS NULL THEN FALSE
      WHEN page_eligibility.has_disallowed_source THEN FALSE
      ELSE TRUE
    END,
    noindex_reason = CASE
      WHEN page_eligibility.has_development_source THEN 'development_fixture'
      WHEN city_page.status <> 'published' THEN 'not_published'
      WHEN city_page.direct_counterpart_city_count = 0 THEN 'no_direct_routes'
      WHEN city_page.content_reviewed_at IS NULL THEN 'content_not_reviewed'
      WHEN page_eligibility.has_disallowed_source THEN 'source_not_seo_eligible'
      ELSE NULL
    END,
    updated_at = now()
  FROM page_eligibility
  WHERE city_page.id = page_eligibility.city_page_id;

  -- STEP 05: Refresh airport facts from the same eligible route version.
  WITH airport_facts AS (
    SELECT
      airport_page.id AS airport_page_id,
      count(DISTINCT outbound_route.destination_city_id)::INTEGER
        AS outbound_destination_count,
      count(DISTINCT outbound_route.destination_country_id)::INTEGER
        AS outbound_country_count,
      count(DISTINCT inbound_route.origin_city_id)::INTEGER
        AS inbound_origin_count,
      count(DISTINCT inbound_route.origin_country_id)::INTEGER
        AS inbound_country_count,
      (
        SELECT count(DISTINCT route.operating_airline_id)::INTEGER
        FROM public.pseo_direct_routes route
        WHERE route.data_version = v_data_version
          AND (
            route.origin_airport_id = airport_page.airport_id
            OR route.destination_airport_id = airport_page.airport_id
          )
      ) AS airline_count,
      (
        SELECT min(route.shortest_duration_minutes)
        FROM public.pseo_direct_routes route
        WHERE route.data_version = v_data_version
          AND (
            route.origin_airport_id = airport_page.airport_id
            OR route.destination_airport_id = airport_page.airport_id
          )
      ) AS shortest_route_minutes,
      (
        SELECT max(route.longest_duration_minutes)
        FROM public.pseo_direct_routes route
        WHERE route.data_version = v_data_version
          AND (
            route.origin_airport_id = airport_page.airport_id
            OR route.destination_airport_id = airport_page.airport_id
          )
      ) AS longest_route_minutes,
      (
        SELECT min(route.source_freshness_at)
        FROM public.pseo_direct_routes route
        WHERE route.data_version = v_data_version
          AND (
            route.origin_airport_id = airport_page.airport_id
            OR route.destination_airport_id = airport_page.airport_id
          )
      ) AS source_freshness_at
    FROM public.airport_pages airport_page
    LEFT JOIN public.pseo_direct_routes outbound_route
      ON outbound_route.origin_airport_id = airport_page.airport_id
      AND outbound_route.data_version = v_data_version
    LEFT JOIN public.pseo_direct_routes inbound_route
      ON inbound_route.destination_airport_id = airport_page.airport_id
      AND inbound_route.data_version = v_data_version
    GROUP BY airport_page.id
  )
  UPDATE public.airport_pages airport_page
  SET
    outbound_destination_count = airport_facts.outbound_destination_count,
    outbound_country_count = airport_facts.outbound_country_count,
    inbound_origin_count = airport_facts.inbound_origin_count,
    inbound_country_count = airport_facts.inbound_country_count,
    airline_count = airport_facts.airline_count,
    shortest_route_minutes = airport_facts.shortest_route_minutes,
    longest_route_minutes = airport_facts.longest_route_minutes,
    source_freshness_at = airport_facts.source_freshness_at,
    data_version = v_data_version,
    generated_at = now(),
    updated_at = now()
  FROM airport_facts
  WHERE airport_page.id = airport_facts.airport_page_id;

  GET DIAGNOSTICS v_airport_page_count = ROW_COUNT;

  WITH airport_eligibility AS (
    SELECT
      airport_page.id AS airport_page_id,
      airport.status AS airport_status,
      airport.iata,
      EXISTS (
        SELECT 1
        FROM public.airport_access_options access
        WHERE access.airport_page_id = airport_page.id
          AND access.status = 'published'
          AND access.last_verified_at IS NOT NULL
      ) AS has_access,
      EXISTS (
        SELECT 1
        FROM public.pseo_direct_routes route
        JOIN public.flight_routes flight_route
          ON flight_route.id = route.flight_route_id
        JOIN admin.data_sources data_source
          ON data_source.id = flight_route.source_id
        WHERE route.data_version = v_data_version
          AND (
            route.origin_airport_id = airport_page.airport_id
            OR route.destination_airport_id = airport_page.airport_id
          )
          AND data_source.environment_scope = 'development'
      ) AS has_development_source,
      EXISTS (
        SELECT 1
        FROM public.pseo_direct_routes route
        JOIN public.flight_routes flight_route
          ON flight_route.id = route.flight_route_id
        JOIN admin.data_sources data_source
          ON data_source.id = flight_route.source_id
        WHERE route.data_version = v_data_version
          AND (
            route.origin_airport_id = airport_page.airport_id
            OR route.destination_airport_id = airport_page.airport_id
          )
          AND (
            data_source.production_allowed = FALSE
            OR data_source.seo_allowed = FALSE
            OR data_source.derived_data_allowed = FALSE
          )
      ) AS has_disallowed_source
    FROM public.airport_pages airport_page
    JOIN public.airports airport
      ON airport.id = airport_page.airport_id
  )
  UPDATE public.airport_pages airport_page
  SET
    is_indexable = CASE
      WHEN airport_eligibility.has_development_source THEN FALSE
      WHEN airport_page.status <> 'published' THEN FALSE
      WHEN airport_eligibility.airport_status <> 'active' THEN FALSE
      WHEN airport_eligibility.iata IS NULL THEN FALSE
      WHEN airport_page.outbound_destination_count + airport_page.inbound_origin_count = 0 THEN FALSE
      WHEN airport_page.content_reviewed_at IS NULL THEN FALSE
      WHEN airport_eligibility.has_access = FALSE THEN FALSE
      WHEN airport_eligibility.has_disallowed_source THEN FALSE
      ELSE TRUE
    END,
    noindex_reason = CASE
      WHEN airport_eligibility.has_development_source THEN 'development_fixture'
      WHEN airport_page.status <> 'published' THEN 'not_published'
      WHEN airport_eligibility.airport_status <> 'active' THEN 'airport_inactive'
      WHEN airport_eligibility.iata IS NULL THEN 'missing_iata'
      WHEN airport_page.outbound_destination_count + airport_page.inbound_origin_count = 0
        THEN 'no_direct_routes'
      WHEN airport_page.content_reviewed_at IS NULL THEN 'content_not_reviewed'
      WHEN airport_eligibility.has_access = FALSE THEN 'missing_access_information'
      WHEN airport_eligibility.has_disallowed_source THEN 'source_not_seo_eligible'
      ELSE NULL
    END,
    updated_at = now()
  FROM airport_eligibility
  WHERE airport_page.id = airport_eligibility.airport_page_id;

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

  UPDATE public.pseo_pages pseo_page
  SET
    status = airport_page.status,
    is_indexable = airport_page.is_indexable,
    noindex_reason = airport_page.noindex_reason,
    data_version = airport_page.data_version,
    source_freshness_at = airport_page.source_freshness_at,
    generated_at = airport_page.generated_at
  FROM public.airport_pages airport_page
  WHERE airport_page.pseo_page_id = pseo_page.id;

  UPDATE public.pseo_internal_links
  SET
    data_version = v_data_version,
    generated_at = now();

  -- STEP 06: Return deterministic refresh evidence.
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'data_version', v_data_version,
      'direct_routes', v_route_count,
      'destination_summaries', v_destination_count,
      'city_pages', v_page_count,
      'airport_pages', v_airport_page_count
    ),
    'meta', jsonb_build_object(
      'generated_at', now()
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_pseo_read_models()
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_pseo_read_models() TO service_role;
