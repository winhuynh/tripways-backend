-- ============================================================================
-- Function: private.build_city_page_payload
-- Feature: Interactive pSEO
-- Purpose: Return one bounded, frontend-ready city pSEO page payload.
-- Responsibilities: Validate identity, resolve reviewed content, and group page modules.
-- Notes: Indexability metadata is returned from Postgres and is never inferred by the transport.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.build_city_page_payload(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Input
  ------------------------------------------------------------------
  v_city_slug TEXT;
  v_locale TEXT;
  v_route_direction TEXT;
  v_destination_limit INTEGER := 8;

  ------------------------------------------------------------------
  -- Resolved page
  ------------------------------------------------------------------
  v_city_id UUID;
  v_city_page_id UUID;
  v_pseo_page_id UUID;
  v_publication_version_id UUID;
  v_identity JSONB;
  v_context JSONB;
  v_result JSONB;
BEGIN
  -- STEP 01: Parse the city-page identity shared by pSEO read RPCs.
  v_identity := private.parse_city_page_identity(p_input);

  IF v_identity #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      v_identity #>> '{error,code}',
      v_identity #>> '{error,message}'
    );
  END IF;

  v_city_slug := v_identity #>> '{data,city_slug}';
  v_locale := v_identity #>> '{data,locale}';
  v_route_direction := v_identity #>> '{data,route_direction}';

  BEGIN
    v_publication_version_id := (p_input->>'publication_version_id')::UUID;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN private.build_rpc_error('null'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid publication version.');
  END;

  IF v_publication_version_id IS NULL THEN
    RETURN private.build_rpc_error('null'::JSONB, 'ERR_INVALID_REQUEST', 'Publication version is required.');
  END IF;

  IF p_input ? 'destination_limit' THEN
    IF jsonb_typeof(p_input->'destination_limit') <> 'number' THEN
      RETURN private.build_rpc_error(
        'null'::JSONB,
        'ERR_INVALID_REQUEST',
        'destination_limit must be an integer.'
      );
    END IF;
    v_destination_limit := (p_input->>'destination_limit')::INTEGER;
  END IF;

  IF v_destination_limit NOT BETWEEN 1 AND 24 THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      'ERR_INVALID_REQUEST',
      'destination_limit is outside accepted bounds.'
    );
  END IF;

  -- STEP 02: Resolve the city and reviewed page identity.
  v_context := private.resolve_city_page_context(
    v_city_slug,
    v_locale,
    v_route_direction
  );

  IF v_context #>> '{error,code}' IS NOT NULL THEN
    RETURN private.build_rpc_error(
      'null'::JSONB,
      v_context #>> '{error,code}',
      v_context #>> '{error,message}'
    );
  END IF;

  v_city_id := (v_context #>> '{data,city_id}')::UUID;
  v_city_page_id := (v_context #>> '{data,city_page_id}')::UUID;
  v_pseo_page_id := (v_context #>> '{data,pseo_page_id}')::UUID;

  -- STEP 03: Assemble a bounded page payload from one published data version.
  SELECT jsonb_build_object(
    'data', jsonb_build_object(
      'city', jsonb_build_object(
        'id', city.id,
        'name', city.name,
        'slug', city.slug,
        'latitude', city.latitude,
        'longitude', city.longitude,
        'timezone', city.timezone
      ),
      'country', jsonb_build_object(
        'iso2', country.iso2,
        'iso3', country.iso3,
        'name', country.name,
        'slug', country.slug,
        'region', country.region,
        'subregion', country.subregion
      ),
      'page', jsonb_build_object(
        'h1', city_page.h1,
        'subheadline', city_page.subheadline,
        'seo_title', city_page.seo_title,
        'meta_description', city_page.meta_description,
        'og_title', city_page.og_title,
        'og_description', city_page.og_description,
        'og_image_path', city_page.og_image_path,
        'intro', city_page.intro,
        'airport_summary', city_page.airport_summary,
        'status', pseo_page.status
      ),
      'airports', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'iata', airport.iata,
            'icao', airport.icao,
            'name', airport.name,
            'slug', airport.slug,
            'airport_type', airport.airport_type,
            'latitude', airport.latitude,
            'longitude', airport.longitude,
            'timezone', airport.timezone,
            'is_primary', airport.id = city_page.primary_airport_id,
            'direct_destinations', (
              SELECT count(DISTINCT route.destination_city_id)
              FROM public.route_search_options AS route
              WHERE route.publication_version_id = v_publication_version_id
                AND route.origin_airport_id = airport.id
                AND route.stop_count = 0
            ),
            'airlines', (
              SELECT count(DISTINCT airline_iata)
              FROM public.route_search_options AS route
              CROSS JOIN LATERAL unnest(route.operating_airline_iatas) AS airline_iata
              WHERE route.publication_version_id = v_publication_version_id
                AND route.origin_airport_id = airport.id
                AND route.stop_count = 0
            )
          )
          ORDER BY
            (airport.id = city_page.primary_airport_id) DESC,
            airport.iata
        )
        FROM public.airports airport
        WHERE airport.city_id = city.id
          AND airport.status = 'active'
      ), '[]'::JSONB),
      'quick_facts', (
        SELECT jsonb_build_object(
          'airports', count(DISTINCT route.origin_airport_id),
          'direct_destinations', count(DISTINCT route.destination_city_id),
          'direct_countries', count(DISTINCT route.destination_country_code),
          'airlines', count(DISTINCT airline_iata),
          'shortest_route_minutes', min(route.total_duration_minutes),
          'longest_route_minutes', max(route.total_duration_minutes)
        )
        FROM public.route_search_options AS route
        CROSS JOIN LATERAL unnest(route.operating_airline_iatas) AS airline_iata
        WHERE route.publication_version_id = v_publication_version_id
          AND route.origin_city_id = city.id
          AND route.stop_count = 0
      ),
      'featured_destinations', COALESCE((
        SELECT jsonb_agg(destination.payload ORDER BY destination.direct_route_count DESC, destination.shortest_duration_minutes, destination.city_name)
        FROM (
          SELECT jsonb_build_object(
              'city', jsonb_build_object(
                'name', destination_city.name,
                'slug', route.destination_city_slug
              ),
              'country', jsonb_build_object(
                'iso2', destination_country.iso2,
                'name', destination_country.name,
                'slug', destination_country.slug
              ),
              'origin_airports', to_jsonb(array_agg(DISTINCT route.origin_airport_iata ORDER BY route.origin_airport_iata)),
              'destination_airports', to_jsonb(array_agg(DISTINCT route.destination_airport_iata ORDER BY route.destination_airport_iata)),
              'airlines', to_jsonb(ARRAY(
                SELECT DISTINCT airline_iata
                FROM public.route_search_options AS airline_route
                CROSS JOIN LATERAL unnest(airline_route.operating_airline_iatas) AS airline_iata
                WHERE airline_route.publication_version_id = v_publication_version_id
                  AND airline_route.origin_city_id = city.id
                  AND airline_route.destination_city_id = route.destination_city_id
                  AND airline_route.stop_count = 0
                ORDER BY airline_iata
              )),
              'direct_route_count', count(*),
              'frequency_per_week', NULL,
              'shortest_duration_minutes', min(route.total_duration_minutes),
              'longest_duration_minutes', max(route.total_duration_minutes),
              'seasonality', NULL,
              'confidence_score', min(route.confidence_score),
              'route_path', min(route.route_path)
            ) AS payload,
            destination_city.name AS city_name,
            count(*)::INTEGER AS direct_route_count,
            min(route.total_duration_minutes) AS shortest_duration_minutes,
            max(route.total_duration_minutes) AS longest_duration_minutes,
            min(route.confidence_score) AS confidence_score,
            array_agg(DISTINCT route.origin_airport_iata ORDER BY route.origin_airport_iata) AS origin_airports,
            array_agg(DISTINCT route.destination_airport_iata ORDER BY route.destination_airport_iata) AS destination_airports,
            ARRAY(
              SELECT DISTINCT airline_iata
              FROM public.route_search_options AS airline_route
              CROSS JOIN LATERAL unnest(airline_route.operating_airline_iatas) AS airline_iata
              WHERE airline_route.publication_version_id = v_publication_version_id
                AND airline_route.origin_city_id = city.id
                AND airline_route.destination_city_id = route.destination_city_id
                AND airline_route.stop_count = 0
              ORDER BY airline_iata
            ) AS airlines,
            route.destination_city_slug,
            min(route.route_path) AS route_path
          FROM public.route_search_options AS route
          JOIN public.cities AS destination_city ON destination_city.id = route.destination_city_id
          JOIN public.countries AS destination_country ON destination_country.id = destination_city.country_id
          WHERE route.publication_version_id = v_publication_version_id
            AND route.origin_city_id = city.id
            AND route.stop_count = 0
            AND route.route_path IS NOT NULL
          GROUP BY route.destination_city_id, route.destination_city_slug, destination_city.name, destination_country.id
          ORDER BY count(*) DESC, min(route.total_duration_minutes), destination_city.name
          LIMIT v_destination_limit
        ) AS destination
      ), '[]'::JSONB),
      'direct_countries', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'iso2', country_summary.iso2,
            'name', country_summary.name,
            'slug', country_summary.slug,
            'direct_destinations', country_summary.direct_destinations
          )
          ORDER BY
            country_summary.direct_destinations DESC,
            country_summary.name
        )
        FROM (
          SELECT
            destination_country.iso2,
            destination_country.name,
            destination_country.slug,
            count(DISTINCT route.destination_city_id) AS direct_destinations
          FROM public.route_search_options AS route
          JOIN public.countries AS destination_country
            ON destination_country.iso2 = route.destination_country_code
          WHERE route.publication_version_id = v_publication_version_id
            AND route.origin_city_id = city.id
            AND route.stop_count = 0
          GROUP BY destination_country.id
        ) country_summary
      ), '[]'::JSONB),
      'faqs', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'question', faq.question,
            'answer', faq.answer,
            'answer_type', faq.answer_type
          )
          ORDER BY faq.display_order
        )
        FROM public.city_page_faqs faq
        WHERE faq.city_page_id = city_page.id
          AND faq.locale = v_locale
          AND faq.status = 'published'
      ), '[]'::JSONB),
      'structured_facts', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'type',fact.fact_type,'title',fact.title,'body',fact.body,'value',fact.structured_value,
        'source_url',fact.primary_source_url,'last_verified_at',fact.last_verified_at
      ) ORDER BY fact.fact_type) FROM public.city_facts fact WHERE fact.city_id=city.id AND fact.locale=v_locale AND fact.status='published'),'[]'::jsonb),
      'price_summary', jsonb_build_object(
        'state',CASE WHEN EXISTS(SELECT 1 FROM public.route_price_estimates estimate JOIN admin.data_sources source ON source.id=estimate.source_id WHERE estimate.origin_city_id=city.id AND estimate.status='published' AND estimate.valid_until>now() AND source.production_display_allowed AND source.derived_data_allowed) THEN 'available' ELSE 'unavailable' END,
        'reason',CASE WHEN EXISTS(SELECT 1 FROM public.route_price_estimates estimate JOIN admin.data_sources source ON source.id=estimate.source_id WHERE estimate.origin_city_id=city.id AND estimate.status='published' AND estimate.valid_until>now() AND source.production_display_allowed AND source.derived_data_allowed) THEN NULL ELSE 'missing' END,
        'currency_ranges',COALESCE((SELECT jsonb_agg(to_jsonb(price_range)) FROM (SELECT estimate.currency_code,min(estimate.price_min) price_min,max(estimate.price_max) price_max FROM public.route_price_estimates estimate JOIN admin.data_sources source ON source.id=estimate.source_id WHERE estimate.origin_city_id=city.id AND estimate.status='published' AND estimate.valid_until>now() AND source.production_display_allowed AND source.derived_data_allowed GROUP BY estimate.currency_code) price_range),'[]'::jsonb)
      ),
      'internal_link_groups', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'cluster', link_group.link_cluster,
            'links', link_group.links
          )
          ORDER BY link_group.cluster_order
        )
        FROM (
          SELECT
            internal_link.link_cluster,
            min(internal_link.display_order) AS cluster_order,
            jsonb_agg(
              jsonb_build_object(
                'title', target_page.display_title,
                'path', target_page.canonical_path,
                'anchor_text', internal_link.anchor_text,
                'secondary_text', internal_link.secondary_text,
                'is_featured', internal_link.is_featured
              )
              ORDER BY
                internal_link.display_order,
                internal_link.relevance_score DESC,
                target_page.canonical_path
            ) AS links
          FROM public.pseo_internal_links internal_link
          JOIN public.pseo_pages target_page
            ON target_page.id = internal_link.target_page_id
          WHERE internal_link.source_page_id = v_pseo_page_id
            AND target_page.status <> 'archived'
          GROUP BY internal_link.link_cluster
        ) link_group
      ), '[]'::JSONB)
    ),
    'meta', jsonb_build_object(
      'canonical_path', pseo_page.canonical_path,
      'is_indexable', pseo_page.is_indexable,
      'noindex_reason', pseo_page.noindex_reason,
      'data_version', v_publication_version_id,
      'generated_at', pseo_page.generated_at,
      'source_freshness_at', pseo_page.source_freshness_at
    ),
    'error', NULL
  )
  INTO v_result
  FROM public.cities city
  JOIN public.countries country
    ON country.id = city.country_id
  JOIN public.city_pages city_page
    ON city_page.id = v_city_page_id
  JOIN public.pseo_pages pseo_page
    ON pseo_page.id = city_page.pseo_page_id
  WHERE city.id = v_city_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION private.build_city_page_payload(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.build_city_page_payload(JSONB) TO service_role;
