-- ============================================================================
-- Function: public.rpc_get_airport_page
-- Feature: Interactive pSEO
-- Purpose: Return one frontend-ready airport landing-page payload.
-- Responsibilities: Compose identity, route summaries, reviewed guidance, and page metadata.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_airport_page(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_identity JSONB;
  v_context JSONB;
  v_airport_iata TEXT;
  v_locale TEXT;
  v_airport_id UUID;
  v_airport_page_id UUID;
  v_pseo_page_id UUID;
  v_data_version UUID;
  v_route_limit INTEGER := 8;
  v_result JSONB;
BEGIN
  v_identity := private.parse_airport_page_identity(p_input);

  IF v_identity->'error' IS NOT NULL
    AND v_identity->'error' <> 'null'::JSONB
  THEN
    RETURN jsonb_build_object('data', NULL, 'meta', NULL, 'error', v_identity->'error');
  END IF;

  v_airport_iata := v_identity #>> '{data,airport_iata}';
  v_locale := v_identity #>> '{data,locale}';

  IF p_input ? 'route_limit' THEN
    IF jsonb_typeof(p_input->'route_limit') <> 'number'
      OR (p_input->>'route_limit')::NUMERIC <> trunc((p_input->>'route_limit')::NUMERIC)
      OR (p_input->>'route_limit')::INTEGER NOT BETWEEN 1 AND 24
    THEN
      RETURN jsonb_build_object(
        'data', NULL,
        'meta', NULL,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'route_limit must be an integer between 1 and 24.'
        )
      );
    END IF;

    v_route_limit := (p_input->>'route_limit')::INTEGER;
  END IF;

  v_context := private.resolve_airport_page_context(v_airport_iata, v_locale);

  IF v_context->'error' IS NOT NULL
    AND v_context->'error' <> 'null'::JSONB
  THEN
    RETURN jsonb_build_object('data', NULL, 'meta', NULL, 'error', v_context->'error');
  END IF;

  v_airport_id := (v_context #>> '{data,airport_id}')::UUID;
  v_airport_page_id := (v_context #>> '{data,airport_page_id}')::UUID;
  v_pseo_page_id := (v_context #>> '{data,pseo_page_id}')::UUID;
  v_data_version := (v_context #>> '{data,data_version}')::UUID;

  SELECT jsonb_build_object(
    'data', jsonb_build_object(
      'airport', jsonb_build_object(
        'id', airport.id,
        'iata', airport.iata,
        'icao', airport.icao,
        'name', airport.name,
        'slug', airport.slug,
        'image_path', airport.image_path,
        'type', airport.airport_type,
        'timezone', airport.timezone,
        'latitude', airport.latitude,
        'longitude', airport.longitude,
        'city', jsonb_build_object(
          'id', city.id,
          'name', city.name,
          'slug', city.slug
        ),
        'country', jsonb_build_object(
          'id', country.id,
          'code', country.iso2,
          'name', country.name,
          'slug', country.slug
        )
      ),
      'seo', jsonb_build_object(
        'h1', airport_page.h1,
        'subheadline', airport_page.subheadline,
        'title', airport_page.seo_title,
        'meta_description', airport_page.meta_description,
        'og_title', airport_page.og_title,
        'og_description', airport_page.og_description,
        'og_image_path', airport_page.og_image_path
      ),
      'content', jsonb_build_object(
        'intro', airport_page.intro,
        'route_summary', airport_page.route_summary,
        'access_summary', airport_page.access_summary,
        'parking_summary', airport_page.parking_summary,
        'lounge_summary', airport_page.lounge_summary
      ),
      'quick_facts', jsonb_build_object(
        'outbound_destinations', airport_page.outbound_destination_count,
        'outbound_countries', airport_page.outbound_country_count,
        'inbound_origins', airport_page.inbound_origin_count,
        'inbound_countries', airport_page.inbound_country_count,
        'airlines', airport_page.airline_count,
        'shortest_route_minutes', airport_page.shortest_route_minutes,
        'longest_route_minutes', airport_page.longest_route_minutes
      ),
      'featured_outbound_routes', COALESCE((
        SELECT jsonb_agg(to_jsonb(route_item) ORDER BY route_item.rank_order)
        FROM (
          SELECT
            destination_airport.iata AS airport_iata,
            destination_airport.name AS airport_name,
            destination_city.name AS city_name,
            destination_city.slug AS city_slug,
            destination_country.iso2 AS country_code,
            destination_country.name AS country_name,
            min(route.shortest_duration_minutes) AS shortest_duration_minutes,
            count(DISTINCT route.operating_airline_id)::INTEGER AS airline_count,
            row_number() OVER (
              ORDER BY
                COALESCE(sum(route.frequency_per_week), 0) DESC,
                count(*) DESC,
                destination_city.name,
                destination_airport.iata
            ) AS rank_order
          FROM public.pseo_direct_routes route
          JOIN public.airports destination_airport
            ON destination_airport.id = route.destination_airport_id
          JOIN public.cities destination_city
            ON destination_city.id = route.destination_city_id
          JOIN public.countries destination_country
            ON destination_country.id = route.destination_country_id
          WHERE route.origin_airport_id = v_airport_id
            AND route.data_version = v_data_version
          GROUP BY
            destination_airport.iata,
            destination_airport.name,
            destination_city.name,
            destination_city.slug,
            destination_country.iso2,
            destination_country.name
          ORDER BY rank_order
          LIMIT v_route_limit
        ) route_item
      ), '[]'::JSONB),
      'featured_inbound_routes', COALESCE((
        SELECT jsonb_agg(to_jsonb(route_item) ORDER BY route_item.rank_order)
        FROM (
          SELECT
            origin_airport.iata AS airport_iata,
            origin_airport.name AS airport_name,
            origin_city.name AS city_name,
            origin_city.slug AS city_slug,
            origin_country.iso2 AS country_code,
            origin_country.name AS country_name,
            min(route.shortest_duration_minutes) AS shortest_duration_minutes,
            count(DISTINCT route.operating_airline_id)::INTEGER AS airline_count,
            row_number() OVER (
              ORDER BY
                COALESCE(sum(route.frequency_per_week), 0) DESC,
                count(*) DESC,
                origin_city.name,
                origin_airport.iata
            ) AS rank_order
          FROM public.pseo_direct_routes route
          JOIN public.airports origin_airport
            ON origin_airport.id = route.origin_airport_id
          JOIN public.cities origin_city
            ON origin_city.id = route.origin_city_id
          JOIN public.countries origin_country
            ON origin_country.id = route.origin_country_id
          WHERE route.destination_airport_id = v_airport_id
            AND route.data_version = v_data_version
          GROUP BY
            origin_airport.iata,
            origin_airport.name,
            origin_city.name,
            origin_city.slug,
            origin_country.iso2,
            origin_country.name
          ORDER BY rank_order
          LIMIT v_route_limit
        ) route_item
      ), '[]'::JSONB),
      'airlines', COALESCE((
        SELECT jsonb_agg(to_jsonb(airline_item) ORDER BY airline_item.route_count DESC, airline_item.name)
        FROM (
          SELECT
            airline.iata,
            airline.name,
            airline.slug,
            airline.logo_path,
            count(DISTINCT route.flight_route_id)::INTEGER AS route_count
          FROM public.pseo_direct_routes route
          JOIN public.airlines airline
            ON airline.id = route.operating_airline_id
          WHERE route.data_version = v_data_version
            AND (
              route.origin_airport_id = v_airport_id
              OR route.destination_airport_id = v_airport_id
            )
          GROUP BY airline.iata, airline.name, airline.slug, airline.logo_path
        ) airline_item
      ), '[]'::JSONB),
      'access_options', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'type', access.access_type,
            'name', access.name,
            'destination_label', access.destination_label,
            'summary', access.summary,
            'duration_min_minutes', access.duration_min_minutes,
            'duration_max_minutes', access.duration_max_minutes,
            'price_min', access.price_min,
            'price_max', access.price_max,
            'currency_code', access.currency_code,
            'operating_hours_summary', access.operating_hours_summary,
            'booking_url', access.booking_url,
            'source_url', access.primary_source_url,
            'last_verified_at', access.last_verified_at
          )
          ORDER BY access.display_order
        )
        FROM public.airport_access_options access
        WHERE access.airport_page_id = v_airport_page_id
          AND access.status = 'published'
      ), '[]'::JSONB),
      'parking', (
        SELECT jsonb_build_object(
          'summary', parking.summary,
          'short_stay_available', parking.short_stay_available,
          'long_stay_available', parking.long_stay_available,
          'reservation_available', parking.reservation_available,
          'shuttle_available', parking.shuttle_available,
          'official_url', parking.official_url,
          'source_url', parking.primary_source_url,
          'last_verified_at', parking.last_verified_at
        )
        FROM public.airport_parking_information parking
        WHERE parking.airport_page_id = v_airport_page_id
          AND parking.status = 'published'
      ),
      'lounges', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'name', lounge.name,
            'location_summary', lounge.location_summary,
            'location_type', lounge.location_type,
            'access_summary', lounge.access_summary,
            'amenities', to_jsonb(lounge.amenities),
            'official_url', lounge.official_url,
            'source_url', lounge.primary_source_url,
            'last_verified_at', lounge.last_verified_at
          )
          ORDER BY lounge.display_order
        )
        FROM public.airport_lounges lounge
        WHERE lounge.airport_page_id = v_airport_page_id
          AND lounge.status = 'published'
      ), '[]'::JSONB),
      'notices', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'type', notice.notice_type,
            'title', notice.title,
            'body', notice.body,
            'severity', notice.severity,
            'source_url', notice.primary_source_url,
            'last_verified_at', notice.last_verified_at
          )
          ORDER BY notice.display_order
        )
        FROM public.airport_page_notices notice
        WHERE notice.airport_page_id = v_airport_page_id
          AND notice.status = 'published'
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
        FROM public.airport_page_faqs faq
        WHERE faq.airport_page_id = v_airport_page_id
          AND faq.status = 'published'
      ), '[]'::JSONB),
      'internal_link_groups', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'cluster', links.link_cluster,
            'links', links.items
          )
          ORDER BY links.link_cluster
        )
        FROM (
          SELECT
            link.link_cluster,
            jsonb_agg(
              jsonb_build_object(
                'anchor_text', link.anchor_text,
                'secondary_text', link.secondary_text,
                'path', target.canonical_path
              )
              ORDER BY link.display_order
            ) AS items
          FROM public.pseo_internal_links link
          JOIN public.pseo_pages target
            ON target.id = link.target_page_id
          WHERE link.source_page_id = v_pseo_page_id
            AND target.status = 'published'
          GROUP BY link.link_cluster
        ) links
      ), '[]'::JSONB)
    ),
    'meta', jsonb_build_object(
      'canonical_path', pseo_page.canonical_path,
      'is_indexable', airport_page.is_indexable,
      'noindex_reason', airport_page.noindex_reason,
      'data_version', airport_page.data_version,
      'source_freshness_at', airport_page.source_freshness_at,
      'generated_at', airport_page.generated_at
    ),
    'error', NULL
  )
  INTO v_result
  FROM public.airport_pages airport_page
  JOIN public.pseo_pages pseo_page
    ON pseo_page.id = airport_page.pseo_page_id
  JOIN public.airports airport
    ON airport.id = airport_page.airport_id
  LEFT JOIN public.cities city
    ON city.id = airport.city_id
  JOIN public.countries country
    ON country.id = airport.country_id
  WHERE airport_page.id = v_airport_page_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_airport_page(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_airport_page(JSONB) TO service_role;
