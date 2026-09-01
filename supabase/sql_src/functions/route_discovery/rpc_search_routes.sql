-- ============================================================================
-- Function: public.rpc_search_routes
-- Purpose: Search the pre-computed 0-stop and 1-stop route projections.
-- Responsibilities: Validate supported filters and return a bounded public route payload.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_search_routes(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  v_version_id              UUID;
  v_scope_type              TEXT;
  v_scope_key               TEXT;
  v_scope_from              TEXT;
  v_scope_to                TEXT;
  v_direction               TEXT;
  v_page_size               INTEGER := 20;
  v_offset                  INTEGER := 0;
  v_max_stops               INTEGER;
  v_airlines                TEXT[] := '{}';
  v_connection_airports     TEXT[] := '{}';
  v_departure_airports      TEXT[] := '{}';
  v_destination_countries   TEXT[] := '{}';
  v_destination_regions     TEXT[] := '{}';
  v_counterpart_query       TEXT;
  v_counterpart_countries   TEXT[] := '{}';
  v_counterpart_regions     TEXT[] := '{}';
  v_departure_time_buckets  TEXT[] := '{}';
  v_days_of_week            INTEGER[] := '{}';
  v_route_type              TEXT := 'all';
  v_max_duration_minutes    INTEGER;
  v_max_layover_minutes     INTEGER;
  v_cabin                   TEXT := 'any';
  v_max_amount              NUMERIC;
  v_currency                TEXT;
  v_result                  JSONB;
BEGIN
  IF jsonb_typeof(p_input) IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_input->'scope') IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_input->'filters') IS DISTINCT FROM 'object'
    OR (p_input - ARRAY['scope', 'filters', 'page_size', 'after']) <> '{}'::JSONB
    OR (
      (p_input->'filters') - ARRAY[
        'max_stops', 'airlines', 'connection_airports', 'departure_airports',
        'destination_countries', 'destination_regions', 'counterpart_query',
        'counterpart_countries', 'counterpart_regions', 'departure_time_buckets',
        'days_of_week', 'route_type', 'max_duration_minutes', 'max_layover_minutes',
        'cabin', 'max_amount', 'currency'
      ]
    ) <> '{}'::JSONB
  THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  v_scope_type := p_input #>> '{scope,type}';
  v_scope_key := p_input #>> '{scope,key}';
  v_scope_from := p_input #>> '{scope,from}';
  v_scope_to := p_input #>> '{scope,to}';
  v_direction := p_input #>> '{scope,direction}';

  IF v_scope_type NOT IN ('global', 'origin_city', 'origin_airport', 'airport', 'city_pair')
    OR (v_scope_type IN ('origin_city', 'origin_airport', 'airport') AND NULLIF(btrim(COALESCE(v_scope_key, '')), '') IS NULL)
    OR (v_scope_type = 'airport' AND v_direction NOT IN ('from', 'to'))
    OR (v_scope_type = 'city_pair' AND (NULLIF(v_scope_from, '') IS NULL OR NULLIF(v_scope_to, '') IS NULL OR v_scope_from = v_scope_to))
    OR (p_input ? 'page_size' AND (jsonb_typeof(p_input->'page_size') <> 'number' OR p_input->>'page_size' !~ '^[0-9]+$' OR (p_input->>'page_size')::INTEGER NOT BETWEEN 1 AND 100))
    OR (p_input ? 'after' AND p_input->'after' <> 'null'::JSONB AND (jsonb_typeof(p_input->'after') <> 'string' OR p_input->>'after' !~ '^offset:[0-9]+$'))
  THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  v_page_size := COALESCE((p_input->>'page_size')::INTEGER, 20);
  IF p_input->>'after' IS NOT NULL THEN
    v_offset := split_part(p_input->>'after', ':', 2)::INTEGER;
  END IF;

  IF p_input->'filters' ? 'max_stops' THEN
    IF jsonb_typeof(p_input #> '{filters,max_stops}') <> 'number' OR p_input #>> '{filters,max_stops}' !~ '^[01]$' THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    v_max_stops := (p_input #>> '{filters,max_stops}')::INTEGER;
  END IF;

  IF p_input->'filters' ? 'max_duration_minutes' THEN
    IF jsonb_typeof(p_input #> '{filters,max_duration_minutes}') <> 'number' OR p_input #>> '{filters,max_duration_minutes}' !~ '^[0-9]+$' OR (p_input #>> '{filters,max_duration_minutes}')::INTEGER NOT BETWEEN 1 AND 10080 THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    v_max_duration_minutes := (p_input #>> '{filters,max_duration_minutes}')::INTEGER;
  END IF;

  IF p_input->'filters' ? 'max_layover_minutes' THEN
    IF jsonb_typeof(p_input #> '{filters,max_layover_minutes}') <> 'number' OR p_input #>> '{filters,max_layover_minutes}' !~ '^[0-9]+$' OR (p_input #>> '{filters,max_layover_minutes}')::INTEGER NOT BETWEEN 1 AND 10080 THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    v_max_layover_minutes := (p_input #>> '{filters,max_layover_minutes}')::INTEGER;
  END IF;

  IF p_input->'filters' ? 'route_type' THEN
    IF jsonb_typeof(p_input #> '{filters,route_type}') <> 'string' OR p_input #>> '{filters,route_type}' NOT IN ('all', 'domestic', 'international') THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    v_route_type := p_input #>> '{filters,route_type}';
  END IF;

  IF p_input->'filters' ? 'cabin' THEN
    IF jsonb_typeof(p_input #> '{filters,cabin}') <> 'string' OR p_input #>> '{filters,cabin}' NOT IN ('any', 'economy', 'premium_economy', 'business', 'first') THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    v_cabin := p_input #>> '{filters,cabin}';
  END IF;

  IF p_input->'filters' ? 'counterpart_query' THEN
    IF jsonb_typeof(p_input #> '{filters,counterpart_query}') <> 'string' OR char_length(btrim(p_input #>> '{filters,counterpart_query}')) NOT BETWEEN 1 AND 80 THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    v_counterpart_query := lower(btrim(p_input #>> '{filters,counterpart_query}'));
  END IF;

  IF (p_input->'filters' ? 'max_amount') <> (p_input->'filters' ? 'currency') THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  IF p_input->'filters' ? 'max_amount' THEN
    IF jsonb_typeof(p_input #> '{filters,max_amount}') <> 'number' OR p_input #>> '{filters,max_amount}' !~ '^[0-9]+(?:\.[0-9]+)?$' OR (p_input #>> '{filters,max_amount}')::NUMERIC < 0 OR jsonb_typeof(p_input #> '{filters,currency}') <> 'string' OR p_input #>> '{filters,currency}' !~ '^[A-Z]{3}$' THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    v_max_amount := (p_input #>> '{filters,max_amount}')::NUMERIC;
    v_currency := p_input #>> '{filters,currency}';
  END IF;

  IF p_input->'filters' ? 'airlines' THEN
    IF jsonb_typeof(p_input #> '{filters,airlines}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,airlines}') AS item WHERE jsonb_typeof(item) <> 'string' OR item #>> '{}' !~ '^[A-Z0-9]{2,3}$') THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT item #>> '{}'), '{}') INTO v_airlines FROM jsonb_array_elements(p_input #> '{filters,airlines}') AS item;
  END IF;

  IF p_input->'filters' ? 'connection_airports' THEN
    IF jsonb_typeof(p_input #> '{filters,connection_airports}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,connection_airports}') AS item WHERE jsonb_typeof(item) <> 'string' OR item #>> '{}' !~ '^[A-Z0-9]{3}$') THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT item #>> '{}'), '{}') INTO v_connection_airports FROM jsonb_array_elements(p_input #> '{filters,connection_airports}') AS item;
  END IF;

  IF p_input->'filters' ? 'departure_airports' THEN
    IF jsonb_typeof(p_input #> '{filters,departure_airports}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,departure_airports}') AS item WHERE jsonb_typeof(item) <> 'string' OR item #>> '{}' !~ '^[A-Z0-9]{3}$') THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT item #>> '{}'), '{}') INTO v_departure_airports FROM jsonb_array_elements(p_input #> '{filters,departure_airports}') AS item;
  END IF;

  IF p_input->'filters' ? 'destination_countries' THEN
    IF jsonb_typeof(p_input #> '{filters,destination_countries}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,destination_countries}') AS item WHERE jsonb_typeof(item) <> 'string' OR item #>> '{}' !~ '^[A-Z]{2}$') THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT item #>> '{}'), '{}') INTO v_destination_countries FROM jsonb_array_elements(p_input #> '{filters,destination_countries}') AS item;
  END IF;

  IF p_input->'filters' ? 'counterpart_countries' THEN
    IF jsonb_typeof(p_input #> '{filters,counterpart_countries}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,counterpart_countries}') AS item WHERE jsonb_typeof(item) <> 'string' OR item #>> '{}' !~ '^[A-Z]{2}$') THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT item #>> '{}'), '{}') INTO v_counterpart_countries FROM jsonb_array_elements(p_input #> '{filters,counterpart_countries}') AS item;
  END IF;

  IF p_input->'filters' ? 'destination_regions' THEN
    IF jsonb_typeof(p_input #> '{filters,destination_regions}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,destination_regions}') AS item WHERE jsonb_typeof(item) <> 'string' OR char_length(btrim(item #>> '{}')) NOT BETWEEN 1 AND 80) THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT item #>> '{}'), '{}') INTO v_destination_regions FROM jsonb_array_elements(p_input #> '{filters,destination_regions}') AS item;
  END IF;

  IF p_input->'filters' ? 'counterpart_regions' THEN
    IF jsonb_typeof(p_input #> '{filters,counterpart_regions}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,counterpart_regions}') AS item WHERE jsonb_typeof(item) <> 'string' OR char_length(btrim(item #>> '{}')) NOT BETWEEN 1 AND 80) THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT item #>> '{}'), '{}') INTO v_counterpart_regions FROM jsonb_array_elements(p_input #> '{filters,counterpart_regions}') AS item;
  END IF;

  IF p_input->'filters' ? 'departure_time_buckets' THEN
    IF jsonb_typeof(p_input #> '{filters,departure_time_buckets}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,departure_time_buckets}') AS item WHERE jsonb_typeof(item) <> 'string' OR item #>> '{}' NOT IN ('early_morning', 'morning', 'afternoon', 'evening')) THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT item #>> '{}'), '{}') INTO v_departure_time_buckets FROM jsonb_array_elements(p_input #> '{filters,departure_time_buckets}') AS item;
  END IF;

  IF p_input->'filters' ? 'days_of_week' THEN
    IF jsonb_typeof(p_input #> '{filters,days_of_week}') <> 'array' OR EXISTS (SELECT 1 FROM jsonb_array_elements(p_input #> '{filters,days_of_week}') AS item WHERE jsonb_typeof(item) <> 'number' OR item #>> '{}' !~ '^[1-7]$') THEN
      RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
    END IF;
    SELECT COALESCE(array_agg(DISTINCT (item #>> '{}')::INTEGER), '{}') INTO v_days_of_week FROM jsonb_array_elements(p_input #> '{filters,days_of_week}') AS item;
  END IF;

  SELECT version.id INTO v_version_id FROM public.publication_versions AS version WHERE version.is_current = TRUE;
  IF v_version_id IS NULL THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_ROUTE_DISCOVERY_UNAVAILABLE', 'No route publication is available.');
  END IF;

  WITH filtered AS (
    SELECT option.*, origin_country.region AS origin_region
    FROM public.flight_route_options AS option
    LEFT JOIN public.countries AS origin_country ON origin_country.iso2 = option.origin_country_code
    WHERE option.publication_version_id = v_version_id
      AND (v_scope_type <> 'origin_city' OR option.origin_city_slug = v_scope_key)
      AND (v_scope_type <> 'origin_airport' OR option.origin_airport_iata = upper(v_scope_key))
      AND (v_scope_type <> 'airport' OR (v_direction = 'from' AND option.origin_airport_iata = upper(v_scope_key)) OR (v_direction = 'to' AND option.destination_airport_iata = upper(v_scope_key)))
      AND (v_scope_type <> 'airport' OR option.stops = 0)
      AND (v_scope_type <> 'city_pair' OR (option.origin_city_slug = v_scope_from AND option.destination_city_slug = v_scope_to))
      AND (v_max_stops IS NULL OR option.stops <= v_max_stops)
      AND (cardinality(v_airlines) = 0 OR option.operating_airlines && v_airlines)
      AND (cardinality(v_connection_airports) = 0 OR option.layover_airports && v_connection_airports)
      AND (cardinality(v_departure_airports) = 0 OR option.origin_airport_iata = ANY(v_departure_airports))
      AND (cardinality(v_destination_countries) = 0 OR option.destination_country_code = ANY(v_destination_countries))
      AND (cardinality(v_destination_regions) = 0 OR option.destination_region = ANY(v_destination_regions))
      AND (v_counterpart_query IS NULL OR (v_direction = 'from' AND (replace(option.destination_city_slug, '-', ' ') ILIKE '%' || v_counterpart_query || '%' OR option.destination_airport_iata ILIKE '%' || v_counterpart_query || '%')) OR (v_direction = 'to' AND (replace(option.origin_city_slug, '-', ' ') ILIKE '%' || v_counterpart_query || '%' OR option.origin_airport_iata ILIKE '%' || v_counterpart_query || '%')))
      AND (cardinality(v_counterpart_countries) = 0 OR (v_direction = 'from' AND option.destination_country_code = ANY(v_counterpart_countries)) OR (v_direction = 'to' AND option.origin_country_code = ANY(v_counterpart_countries)))
      AND (cardinality(v_counterpart_regions) = 0 OR (v_direction = 'from' AND option.destination_region = ANY(v_counterpart_regions)) OR (v_direction = 'to' AND origin_country.region = ANY(v_counterpart_regions)))
      AND (cardinality(v_departure_time_buckets) = 0 OR option.departure_time_buckets && v_departure_time_buckets)
      AND (cardinality(v_days_of_week) = 0 OR option.days_of_week && v_days_of_week)
      AND (v_route_type = 'all' OR (v_route_type = 'domestic' AND option.origin_country_code = option.destination_country_code) OR (v_route_type = 'international' AND option.origin_country_code <> option.destination_country_code))
      AND (v_max_duration_minutes IS NULL OR option.total_duration_minutes <= v_max_duration_minutes)
      AND (v_max_layover_minutes IS NULL OR option.layover_minutes <= v_max_layover_minutes)
      AND (v_cabin = 'any' OR v_cabin = ANY(option.cabins))
      AND (v_max_amount IS NULL OR (option.price_currency = v_currency AND option.price_amount <= v_max_amount))
  ),
  paged AS (
    SELECT filtered.* FROM filtered
    ORDER BY stops ASC, total_duration_minutes ASC, confidence_score DESC, id
    OFFSET v_offset LIMIT v_page_size
  ),
  totals AS (SELECT count(*)::INTEGER AS total FROM filtered)
  SELECT jsonb_build_object(
    'data', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'route_ref', 'route_' || md5(
          origin_airport_iata || ':' || destination_airport_iata || ':' ||
          stops::TEXT || ':' || array_to_string(operating_airlines, ',') || ':' ||
          array_to_string(flight_numbers, ',') || ':' || array_to_string(layover_airports, ',')
        ),
        'from', origin_airport_iata,
        'to', destination_airport_iata,
        'origin_country', origin_country_code,
        'destination_country', destination_country_code,
        'is_international', origin_country_code <> destination_country_code,
        'origin_city_slug', origin_city_slug,
        'destination_city_slug', destination_city_slug,
        'stops', stops,
        'connection_airports', layover_airports,
        'layover_airports', layover_airports,
        'operating_airlines', operating_airlines,
        'flight_numbers', flight_numbers,
        'flight_durations_minutes', flight_durations_minutes,
        'total_flight_minutes', (SELECT COALESCE(sum(duration), 0)::INTEGER FROM unnest(flight_durations_minutes) AS duration),
        'layover_minutes', layover_minutes,
        'total_duration_minutes', total_duration_minutes,
        'total_distance_km', total_distance_km,
        'days_of_week', days_of_week,
        'departure_time_buckets', departure_time_buckets,
        'connection_type', route_type,
        'route_path', route_path,
        'confidence_score', confidence_score,
        'price', CASE WHEN price_amount IS NULL THEN jsonb_build_object('state', 'unavailable', 'reason', 'missing') ELSE jsonb_build_object('state', 'available', 'price_min', price_amount, 'price_max', price_amount, 'currency_code', price_currency) END
      ) ORDER BY stops ASC, total_duration_minutes ASC, confidence_score DESC, id) FROM paged
    ), '[]'::JSONB),
    'meta', jsonb_build_object(
      'data_version', 'v_' || md5(v_version_id::TEXT),
      'total', totals.total,
      'page_size', v_page_size,
      'next_cursor', CASE WHEN v_offset + v_page_size < totals.total THEN 'offset:' || (v_offset + v_page_size)::TEXT ELSE NULL END,
      'facets', jsonb_build_object(
        'stops', COALESCE((SELECT jsonb_agg(jsonb_build_object('value', facet.value, 'count', facet.count)) FROM (SELECT stops::TEXT AS value, count(*)::INTEGER AS count FROM filtered GROUP BY stops ORDER BY stops) AS facet), '[]'::JSONB),
        'airlines', COALESCE((SELECT jsonb_agg(jsonb_build_object('value', facet.value, 'count', facet.count)) FROM (SELECT airline AS value, count(*)::INTEGER AS count FROM filtered, unnest(operating_airlines) AS airline GROUP BY airline ORDER BY airline) AS facet), '[]'::JSONB),
        'connections', COALESCE((SELECT jsonb_agg(jsonb_build_object('value', facet.value, 'count', facet.count)) FROM (SELECT airport AS value, count(*)::INTEGER AS count FROM filtered, unnest(layover_airports) AS airport GROUP BY airport ORDER BY airport) AS facet), '[]'::JSONB),
        'countries', COALESCE((SELECT jsonb_agg(jsonb_build_object('value', facet.value, 'count', facet.count)) FROM (SELECT CASE WHEN v_scope_type = 'airport' AND v_direction = 'to' THEN origin_country_code ELSE destination_country_code END AS value, count(*)::INTEGER AS count FROM filtered GROUP BY 1 ORDER BY 1) AS facet), '[]'::JSONB),
        'regions', COALESCE((SELECT jsonb_agg(jsonb_build_object('value', facet.value, 'count', facet.count)) FROM (SELECT CASE WHEN v_scope_type = 'airport' AND v_direction = 'to' THEN origin_region ELSE destination_region END AS value, count(*)::INTEGER AS count FROM filtered WHERE CASE WHEN v_scope_type = 'airport' AND v_direction = 'to' THEN origin_region IS NOT NULL ELSE destination_region IS NOT NULL END GROUP BY 1 ORDER BY 1) AS facet), '[]'::JSONB)
      )
    ),
    'error', NULL
  ) INTO v_result FROM totals;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_routes(JSONB) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_search_routes(JSONB) TO service_role;
