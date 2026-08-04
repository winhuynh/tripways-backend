-- ============================================================================
-- Function: public.rpc_search_route_options_v2
-- Purpose: Search one shared route projection for every page consumer.
-- Responsibilities: Validate scope/filters, apply deterministic keyset pagination, and return facets.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_search_route_options_v2(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_version_id UUID;
  v_scope_type TEXT;
  v_scope_key TEXT;
  v_scope_from TEXT;
  v_scope_to TEXT;
  v_filters JSONB;
  v_max_stops INTEGER;
  v_airlines TEXT[];
  v_connections TEXT[];
  v_max_duration INTEGER;
  v_max_layover INTEGER;
  v_cabin TEXT;
  v_price_max NUMERIC;
  v_currency TEXT;
  v_page_size INTEGER;
  v_cursor_stops INTEGER;
  v_cursor_duration INTEGER;
  v_cursor_confidence NUMERIC;
  v_cursor_id UUID;
  v_result JSONB;
BEGIN
  IF jsonb_typeof(p_input) IS DISTINCT FROM 'object'
    OR p_input - ARRAY['scope', 'filters', 'page_size', 'after'] <> '{}'::JSONB
    OR jsonb_typeof(p_input->'scope') <> 'object'
    OR jsonb_typeof(COALESCE(p_input->'filters', '{}'::JSONB)) <> 'object'
    OR COALESCE(p_input->'filters', '{}'::JSONB)
      - ARRAY[
        'max_stops',
        'airlines',
        'connection_airports',
        'max_duration_minutes',
        'max_layover_minutes',
        'cabin',
        'price_max',
        'currency'
      ] <> '{}'::JSONB
  THEN
    RETURN private.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  v_scope_type := p_input #>> '{scope,type}';
  v_scope_key := p_input #>> '{scope,key}';
  v_scope_from := p_input #>> '{scope,from}';
  v_scope_to := p_input #>> '{scope,to}';
  v_filters := COALESCE(p_input->'filters', '{}'::JSONB);
  v_max_stops := COALESCE((v_filters->>'max_stops')::INTEGER, 3);
  v_max_duration := NULLIF(v_filters->>'max_duration_minutes', '')::INTEGER;
  v_max_layover := NULLIF(v_filters->>'max_layover_minutes', '')::INTEGER;
  v_cabin := COALESCE(NULLIF(v_filters->>'cabin', ''), 'any');
  v_price_max := NULLIF(v_filters->>'price_max', '')::NUMERIC;
  v_currency := upper(NULLIF(btrim(COALESCE(v_filters->>'currency', '')), ''));
  v_page_size := COALESCE((p_input->>'page_size')::INTEGER, 20);

  IF v_scope_type IS NULL
    OR v_scope_type NOT IN ('global', 'origin_city', 'origin_airport', 'city_pair')
    OR (
      v_scope_type = 'global'
      AND (p_input->'scope') - ARRAY['type'] <> '{}'::JSONB
    )
    OR (
      v_scope_type IN ('origin_city', 'origin_airport')
      AND (
        (p_input->'scope') - ARRAY['type', 'key'] <> '{}'::JSONB
        OR NULLIF(btrim(COALESCE(v_scope_key, '')), '') IS NULL
      )
    )
    OR (
      v_scope_type = 'city_pair'
      AND (
        (p_input->'scope') - ARRAY['type', 'from', 'to'] <> '{}'::JSONB
        OR NULLIF(btrim(COALESCE(v_scope_from, '')), '') IS NULL
        OR NULLIF(btrim(COALESCE(v_scope_to, '')), '') IS NULL
        OR v_scope_from = v_scope_to
      )
    )
    OR (v_scope_type = 'origin_airport' AND upper(v_scope_key) !~ '^[A-Z0-9]{3}$')
    OR v_max_stops NOT BETWEEN 0 AND 3
    OR v_page_size NOT BETWEEN 1 AND 100
    OR (v_max_duration IS NOT NULL AND v_max_duration NOT BETWEEN 1 AND 10080)
    OR (v_max_layover IS NOT NULL AND v_max_layover NOT BETWEEN 1 AND 1440)
    OR (v_price_max IS NOT NULL AND v_price_max < 0)
    OR ((v_price_max IS NULL) <> (v_currency IS NULL))
    OR (v_currency IS NOT NULL AND v_currency !~ '^[A-Z]{3}$')
    OR v_cabin NOT IN ('any', 'economy', 'premium_economy', 'business', 'first')
    OR (v_filters ? 'airlines' AND jsonb_typeof(v_filters->'airlines') <> 'array')
    OR (
      v_filters ? 'connection_airports'
      AND jsonb_typeof(v_filters->'connection_airports') <> 'array'
    )
  THEN
    RETURN private.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  IF v_filters ? 'airlines' THEN
    SELECT COALESCE(array_agg(DISTINCT upper(value)), '{}'::TEXT[])
    INTO v_airlines
    FROM jsonb_array_elements_text(v_filters->'airlines');
  ELSE
    v_airlines := '{}'::TEXT[];
  END IF;

  IF v_filters ? 'connection_airports' THEN
    SELECT COALESCE(array_agg(DISTINCT upper(value)), '{}'::TEXT[])
    INTO v_connections
    FROM jsonb_array_elements_text(v_filters->'connection_airports');
  ELSE
    v_connections := '{}'::TEXT[];
  END IF;

  IF EXISTS (SELECT 1 FROM unnest(v_airlines) code WHERE code !~ '^[A-Z0-9]{2}$')
    OR EXISTS (SELECT 1 FROM unnest(v_connections) code WHERE code !~ '^[A-Z0-9]{3}$')
  THEN
    RETURN private.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route code filter.');
  END IF;

  SELECT version.id
  INTO v_version_id
  FROM public.publication_versions version
  WHERE version.is_current = TRUE;

  IF v_version_id IS NULL THEN
    RETURN private.build_rpc_error('[]'::JSONB, 'ERR_ROUTE_DISCOVERY_UNAVAILABLE', 'No route publication is available.');
  END IF;

  IF p_input->>'after' IS NOT NULL THEN
    BEGIN
      v_cursor_stops := split_part(p_input->>'after', ':', 1)::INTEGER;
      v_cursor_duration := split_part(p_input->>'after', ':', 2)::INTEGER;
      v_cursor_confidence := split_part(p_input->>'after', ':', 3)::NUMERIC;
      v_cursor_id := split_part(p_input->>'after', ':', 4)::UUID;
    EXCEPTION WHEN OTHERS THEN
      RETURN private.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route cursor.');
    END;
  END IF;

  WITH filtered AS MATERIALIZED (
    SELECT option.*
    FROM public.route_search_options option
    WHERE option.publication_version_id = v_version_id
      AND option.stop_count <= v_max_stops
      AND (v_scope_type <> 'origin_city' OR option.origin_city_slug = v_scope_key)
      AND (v_scope_type <> 'origin_airport' OR option.origin_airport_iata = upper(v_scope_key))
      AND (v_scope_type <> 'city_pair' OR (option.origin_city_slug = v_scope_from AND option.destination_city_slug = v_scope_to))
      AND (v_max_duration IS NULL OR option.total_duration_minutes <= v_max_duration)
      AND (v_max_layover IS NULL OR option.maximum_layover_minutes <= v_max_layover)
      AND (cardinality(v_airlines) = 0 OR option.operating_airline_iatas && v_airlines)
      AND (cardinality(v_connections) = 0 OR option.connection_airport_iatas && v_connections)
      AND (v_price_max IS NULL OR (option.price_state = 'available' AND option.price_min <= v_price_max AND option.currency_code = v_currency))
  ),
  page AS (
    SELECT filtered.*
    FROM filtered
    WHERE v_cursor_id IS NULL
      OR (filtered.stop_count, filtered.total_duration_minutes, -filtered.confidence_score, filtered.id)
        > (v_cursor_stops, v_cursor_duration, -v_cursor_confidence, v_cursor_id)
    ORDER BY filtered.stop_count, filtered.total_duration_minutes, filtered.confidence_score DESC, filtered.id
    LIMIT v_page_size
  )
  SELECT jsonb_build_object(
    'data', COALESCE((SELECT jsonb_agg(jsonb_build_object(
      'id', page.id,
      'from', page.origin_airport_iata,
      'to', page.destination_airport_iata,
      'stops', page.stop_count,
      'connection_airports', to_jsonb(page.connection_airport_iatas),
      'operating_airlines', to_jsonb(page.operating_airline_iatas),
      'total_flight_minutes', page.total_flight_minutes,
      'layover_minutes', page.layover_minutes,
      'total_duration_minutes', page.total_duration_minutes,
      'schedule', jsonb_build_object('departure_local_time', page.departure_local_time, 'arrival_local_time', page.arrival_local_time, 'arrival_day_offset', page.arrival_day_offset, 'days_of_week', page.days_of_week, 'valid_from', page.valid_from, 'valid_to', page.valid_to),
      'route_path', page.route_path,
      'price', CASE WHEN page.price_state = 'available' THEN jsonb_build_object('state','available','price_min',page.price_min,'price_max',page.price_max,'currency_code',page.currency_code,'valid_until',page.price_valid_until) ELSE jsonb_build_object('state','unavailable','reason',page.price_state,'estimate',NULL) END,
      'self_transfer', 'unknown', 'through_baggage', 'unknown', 'fare_rules', 'unknown', 'live_availability', 'unknown'
    ) ORDER BY page.stop_count, page.total_duration_minutes, page.confidence_score DESC, page.id) FROM page), '[]'::JSONB),
    'meta', jsonb_build_object(
      'data_version', v_version_id,
      'total', (SELECT count(*) FROM filtered),
      'page_size', v_page_size,
      'next_cursor', (SELECT format('%s:%s:%s:%s', page.stop_count, page.total_duration_minutes, page.confidence_score, page.id) FROM page ORDER BY page.stop_count DESC, page.total_duration_minutes DESC, page.confidence_score, page.id DESC LIMIT 1),
      'facets', jsonb_build_object(
        'stops', (SELECT COALESCE(jsonb_agg(to_jsonb(facet) ORDER BY facet.value), '[]'::JSONB) FROM (SELECT stop_count value, count(*)::INTEGER count FROM filtered GROUP BY stop_count) facet),
        'airlines', (SELECT COALESCE(jsonb_agg(to_jsonb(facet) ORDER BY facet.value), '[]'::JSONB) FROM (SELECT code value, count(*)::INTEGER count FROM filtered CROSS JOIN LATERAL unnest(operating_airline_iatas) code GROUP BY code) facet),
        'connections', (SELECT COALESCE(jsonb_agg(to_jsonb(facet) ORDER BY facet.value), '[]'::JSONB) FROM (SELECT code value, count(*)::INTEGER count FROM filtered CROSS JOIN LATERAL unnest(connection_airport_iatas) code GROUP BY code) facet)
      )
    ),
    'error', NULL
  )
  INTO v_result;

  RETURN v_result;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN private.build_rpc_error(
      '[]'::JSONB,
      'ERR_INVALID_REQUEST',
      'Invalid route search request.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_route_options_v2(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_search_route_options_v2(JSONB) TO service_role;
