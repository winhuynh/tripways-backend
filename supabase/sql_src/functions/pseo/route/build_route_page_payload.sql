-- ============================================================================
-- Function: private.build_route_page_payload
-- Purpose: Compose one reviewed route page during read-model publication.
-- Responsibilities: Join canonical identities, route options, editorial modules and FAQs.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.build_route_page_payload(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_locale TEXT := COALESCE(NULLIF(p_input->>'locale', ''), 'en-GB');
  v_page public.route_pages%ROWTYPE;
  v_pseo public.pseo_pages%ROWTYPE;
BEGIN
  SELECT page.*
  INTO v_page
  FROM public.route_pages page
  WHERE page.canonical_slug = lower(p_input->>'route_slug')
    AND page.locale = v_locale;

  IF v_page.id IS NULL THEN
    RETURN private.build_rpc_error(NULL, 'ERR_NOT_FOUND', 'Route page not found.');
  END IF;

  SELECT page.*
  INTO v_pseo
  FROM public.pseo_pages page
  WHERE page.id = v_page.pseo_page_id;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'route', jsonb_build_object(
        'origin', (
          SELECT jsonb_build_object('name', city.name, 'slug', city.slug)
          FROM public.cities city
          WHERE city.id = v_page.origin_city_id
        ),
        'destination', (
          SELECT jsonb_build_object('name', city.name, 'slug', city.slug)
          FROM public.cities city
          WHERE city.id = v_page.destination_city_id
        )
      ),
      'seo', jsonb_build_object(
        'h1', v_page.h1,
        'subheadline', v_page.subheadline,
        'title', v_page.seo_title,
        'meta_description', v_page.meta_description,
        'intro', v_page.intro
      ),
      'summary', jsonb_build_object(
        'direct_options', v_page.direct_option_count,
        'indirect_options', v_page.indirect_option_count,
        'fastest_direct_minutes', v_page.fastest_direct_minutes,
        'fastest_indirect_minutes', v_page.fastest_indirect_minutes
      ),
      'price', public.resolve_route_price_estimate(
        v_page.origin_city_id,
        v_page.destination_city_id,
        'any',
        'any'
      ),
      'airport_comparison', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'endpoint_role', comparison.endpoint_role,
            'airport_iata', airport.iata,
            'summary', comparison.transfer_summary,
            'duration_min_minutes', comparison.duration_min_minutes,
            'duration_max_minutes', comparison.duration_max_minutes,
            'price_min', comparison.price_min,
            'price_max', comparison.price_max,
            'currency_code', comparison.currency_code,
            'source_url', comparison.primary_source_url
          )
          ORDER BY comparison.display_order
        )
        FROM public.route_page_airport_comparisons comparison
        JOIN public.airports airport
          ON airport.id = comparison.airport_id
        WHERE comparison.route_page_id = v_page.id
          AND comparison.status = 'published'
      ), '[]'::JSONB),
      'travel_facts', COALESCE((
        SELECT jsonb_agg(
          to_jsonb(fact) - 'route_page_id'
          ORDER BY fact.display_order
        )
        FROM public.route_page_travel_facts fact
        WHERE fact.route_page_id = v_page.id
          AND fact.locale = v_locale
          AND fact.status = 'published'
      ), '[]'::JSONB),
      'editorial_sections', COALESCE((
        SELECT jsonb_agg(
          to_jsonb(section) - 'route_page_id'
          ORDER BY section.display_order
        )
        FROM public.route_page_editorial_sections section
        WHERE section.route_page_id = v_page.id
          AND section.locale = v_locale
          AND section.status = 'published'
      ), '[]'::JSONB),
      'faqs', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'question', faq.question,
            'answer', faq.answer,
            'answer_type', faq.answer_type,
            'source_url', faq.primary_source_url,
            'last_verified_at', faq.last_verified_at
          )
          ORDER BY faq.display_order
        )
        FROM public.route_page_faqs faq
        WHERE faq.route_page_id = v_page.id
          AND faq.locale = v_locale
          AND faq.status = 'published'
      ), '[]'::JSONB),
      'unknowns', jsonb_build_object(
        'self_transfer', 'unknown',
        'through_baggage', 'unknown',
        'fare_rules', 'unknown',
        'live_availability', 'unknown'
      ),
      'affiliate', jsonb_build_object(
        'offers', jsonb_build_array(),
        'disclosure', 'Some outbound links may become affiliate links when approved partners are configured. No booking or live fare is currently claimed.'
      )
    ),
    'meta', jsonb_build_object(
      'canonical_path', v_pseo.canonical_path,
      'is_indexable', v_page.is_indexable,
      'noindex_reason', v_page.noindex_reason,
      'data_version', v_page.data_version,
      'source_freshness_at', v_page.source_freshness_at
    ),
    'error', NULL
  );
END;
$$;

REVOKE ALL ON FUNCTION private.build_route_page_payload(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.build_route_page_payload(JSONB) TO service_role;
