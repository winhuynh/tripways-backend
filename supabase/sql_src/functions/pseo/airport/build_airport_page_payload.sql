-- ============================================================================
-- Function: private.build_airport_page_payload
-- Feature: Airport Journey pSEO
-- Purpose: Return one frontend-ready airport journey-guide payload.
-- Responsibilities: Compose reviewed journey content, practical airport modules, and provenance.
-- Notes: Verified flights are queried separately through public.rpc_search_routes.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.build_airport_page_payload(p_input JSONB)
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
  v_publication_version_id UUID := (p_input->>'publication_version_id')::UUID;
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
  v_context := private.resolve_airport_page_context(v_airport_iata, v_locale);

  IF v_context->'error' IS NOT NULL
    AND v_context->'error' <> 'null'::JSONB
  THEN
    RETURN jsonb_build_object('data', NULL, 'meta', NULL, 'error', v_context->'error');
  END IF;

  v_airport_id := (v_context #>> '{data,airport_id}')::UUID;
  v_airport_page_id := (v_context #>> '{data,airport_page_id}')::UUID;
  v_pseo_page_id := (v_context #>> '{data,pseo_page_id}')::UUID;

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
        'city', jsonb_build_object('id', city.id, 'name', city.name, 'slug', city.slug),
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
      'orientation', jsonb_build_object(
        'intro', airport_page.intro,
        'summary', airport_page.orientation_summary,
        'primary_city_area_label', airport_page.primary_city_area_label,
        'city_distance_km', airport_page.city_distance_km,
        'terminal_count', (
          SELECT count(*)::INTEGER
          FROM public.airport_terminals terminal
          WHERE terminal.airport_id = v_airport_id
            AND terminal.status = 'active'
        )
      ),
      'quick_answers', jsonb_build_object(
        'default_transport', (
          SELECT jsonb_build_object(
            'name', access.name,
            'typical_minutes', jsonb_build_object(
              'min', access.duration_min_minutes,
              'max', access.duration_max_minutes
            ),
            'estimated_price', jsonb_build_object(
              'min', access.price_min,
              'max', access.price_max,
              'currency', access.currency_code
            ),
            'last_verified_at', access.last_verified_at
          )
          FROM public.airport_access_options access
          WHERE access.airport_page_id = v_airport_page_id
            AND access.status = 'published'
            AND access.journey_direction IN ('from_airport', 'both')
          ORDER BY access.display_order
          LIMIT 1
        ),
        'city_distance_km', airport_page.city_distance_km,
        'terminal_count', (
          SELECT count(*)::INTEGER
          FROM public.airport_terminals terminal
          WHERE terminal.airport_id = v_airport_id
            AND terminal.status = 'active'
        )
      ),
      'route_summary', (
        SELECT jsonb_build_object(
          'direct_destinations', count(DISTINCT route.destination_city_id),
          'direct_airlines', count(DISTINCT airline_iata),
          'shortest_route_minutes', min(route.total_duration_minutes),
          'longest_route_minutes', max(route.total_duration_minutes)
        )
        FROM public.route_search_options AS route
        CROSS JOIN LATERAL unnest(route.operating_airline_iatas) AS airline_iata
        WHERE route.publication_version_id = v_publication_version_id
          AND route.origin_airport_id = v_airport_id
          AND route.stop_count = 0
      ),
      'arrival', jsonb_build_object(
        'summary', airport_page.arrival_summary,
        'steps', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'audience', step.audience,
              'title', step.title,
              'body', step.body,
              'source_url', step.primary_source_url,
              'last_verified_at', step.last_verified_at
            )
            ORDER BY step.audience, step.display_order
          )
          FROM public.airport_journey_steps step
          WHERE step.airport_page_id = v_airport_page_id
            AND step.locale = v_locale
            AND step.journey_type = 'arrival'
            AND step.status = 'published'
        ), '[]'::JSONB)
      ),
      'departure', jsonb_build_object(
        'summary', airport_page.departure_summary,
        'steps', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object(
              'audience', step.audience,
              'title', step.title,
              'body', step.body,
              'source_url', step.primary_source_url,
              'last_verified_at', step.last_verified_at
            )
            ORDER BY step.audience, step.display_order
          )
          FROM public.airport_journey_steps step
          WHERE step.airport_page_id = v_airport_page_id
            AND step.locale = v_locale
            AND step.journey_type = 'departure'
            AND step.status = 'published'
        ), '[]'::JSONB)
      ),
      'transport', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'direction', access.journey_direction,
            'type', access.access_type,
            'name', access.name,
            'destination_label', access.destination_label,
            'summary', access.summary,
            'duration', jsonb_build_object(
              'min_minutes', access.duration_min_minutes,
              'max_minutes', access.duration_max_minutes
            ),
            'estimated_price', jsonb_build_object(
              'min', access.price_min,
              'max', access.price_max,
              'currency', access.currency_code
            ),
            'operating_hours_summary', access.operating_hours_summary,
            'pickup_location_summary', access.pickup_location_summary,
            'best_for_label', access.best_for_label,
            'luggage_summary', access.luggage_summary,
            'accessibility_summary', access.accessibility_summary,
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
        SELECT to_jsonb(parking)
          - 'id'
          - 'airport_page_id'
          - 'created_at'
          - 'updated_at'
          - 'status'
        FROM public.airport_parking_information parking
        WHERE parking.airport_page_id = v_airport_page_id
          AND parking.status = 'published'
      ),
      'terminals', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'code', terminal.code,
            'name', terminal.name,
            'status', terminal.status
          )
          ORDER BY terminal.code
        )
        FROM public.airport_terminals terminal
        WHERE terminal.airport_id = v_airport_id
      ), '[]'::JSONB),
      'facilities', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'category', facility.category,
            'name', facility.name,
            'summary', facility.summary,
            'operating_hours', facility.operating_hours,
            'source_url', facility.primary_source_url,
            'last_verified_at', facility.last_verified_at
          )
          ORDER BY facility.display_order
        )
        FROM public.airport_facilities facility
        WHERE facility.airport_id = v_airport_id
          AND facility.locale = v_locale
          AND facility.status = 'published'
      ), '[]'::JSONB),
      'lounges', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'name', lounge.name,
            'location_summary', lounge.location_summary,
            'location_type', lounge.location_type,
            'access_summary', lounge.access_summary,
            'operating_hours_summary', lounge.operating_hours_summary,
            'amenities', to_jsonb(lounge.amenities),
            'estimated_price', CASE
              WHEN lounge.estimated_price_min IS NULL THEN NULL
              ELSE jsonb_build_object(
                'min', lounge.estimated_price_min,
                'max', lounge.estimated_price_max,
                'currency', lounge.currency_code
              )
            END,
            'affiliate_url', lounge.affiliate_url,
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
        SELECT jsonb_agg(to_jsonb(notice) - 'id' - 'airport_page_id' - 'created_at' - 'updated_at' - 'status' ORDER BY notice.display_order)
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
          AND faq.locale = v_locale
          AND faq.status = 'published'
      ), '[]'::JSONB),
      'internal_link_groups', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object('cluster', links.link_cluster, 'links', links.items)
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
      ), '[]'::JSONB),
      'provenance', jsonb_build_object(
        'last_editorial_review', airport_page.content_reviewed_at,
        'source_freshness_at', pseo_page.source_freshness_at,
        'route_data_refreshed_at', pseo_page.source_freshness_at,
        'data_version', v_publication_version_id,
        'estimates_are_live', FALSE
      )
    ),
    'meta', jsonb_build_object(
      'canonical_path', pseo_page.canonical_path,
      'is_indexable', pseo_page.is_indexable,
      'noindex_reason', pseo_page.noindex_reason,
      'data_version', v_publication_version_id,
      'source_freshness_at', pseo_page.source_freshness_at,
      'generated_at', pseo_page.generated_at
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

REVOKE ALL ON FUNCTION private.build_airport_page_payload(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.build_airport_page_payload(JSONB) TO service_role;
