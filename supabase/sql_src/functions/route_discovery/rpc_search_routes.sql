-- ============================================================================
-- Function: public.rpc_search_routes
-- Purpose: Search the current lean route projection.
-- Responsibilities: Validate supported filters and return a bounded public route payload.
-- Notes: Schedule-specific filters are intentionally unsupported.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_search_routes(p_input JSONB)
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
  v_page_size INTEGER;
  v_currency TEXT;
  v_max_amount NUMERIC;
  v_result JSONB;
BEGIN
  IF jsonb_typeof(p_input) IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_input->'scope') IS DISTINCT FROM 'object'
    OR p_input - ARRAY['scope', 'filters', 'page_size'] <> '{}'::JSONB
    OR COALESCE(p_input->'filters', '{}'::JSONB) - ARRAY['currency', 'max_amount'] <> '{}'::JSONB
  THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  v_scope_type := p_input #>> '{scope,type}';
  v_scope_key := p_input #>> '{scope,key}';
  v_scope_from := p_input #>> '{scope,from}';
  v_scope_to := p_input #>> '{scope,to}';
  v_page_size := COALESCE((p_input->>'page_size')::INTEGER, 20);
  v_currency := upper(NULLIF(p_input #>> '{filters,currency}', ''));
  v_max_amount := NULLIF(p_input #>> '{filters,max_amount}', '')::NUMERIC;

  IF v_scope_type NOT IN ('global', 'origin_city', 'origin_airport', 'city_pair')
    OR v_page_size NOT BETWEEN 1 AND 100
    OR (v_currency IS NOT NULL AND v_currency !~ '^[A-Z]{3}$')
    OR (v_max_amount IS NOT NULL AND (v_max_amount < 0 OR v_currency IS NULL))
    OR (
      v_scope_type IN ('origin_city', 'origin_airport')
      AND NULLIF(btrim(COALESCE(v_scope_key, '')), '') IS NULL
    )
    OR (
      v_scope_type = 'city_pair'
      AND (
        NULLIF(v_scope_from, '') IS NULL
        OR NULLIF(v_scope_to, '') IS NULL
        OR v_scope_from = v_scope_to
      )
    )
  THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_INVALID_REQUEST', 'Invalid route search request.');
  END IF;

  SELECT version.id
  INTO v_version_id
  FROM public.publication_versions AS version
  WHERE version.is_current = TRUE;
  IF v_version_id IS NULL THEN
    RETURN admin.build_rpc_error('[]'::JSONB, 'ERR_ROUTE_DISCOVERY_UNAVAILABLE', 'No route publication is available.');
  END IF;

  WITH filtered AS (
    SELECT option.*
    FROM public.flight_route_options option
    WHERE option.publication_version_id = v_version_id
      AND (v_scope_type <> 'origin_city' OR option.origin_city_slug = v_scope_key)
      AND (v_scope_type <> 'origin_airport' OR option.origin_airport_iata = upper(v_scope_key))
      AND (
        v_scope_type <> 'city_pair'
        OR (
          option.origin_city_slug = v_scope_from
          AND option.destination_city_slug = v_scope_to
        )
      )
      AND (
        v_max_amount IS NULL
        OR (
          option.observed_amount <= v_max_amount
          AND option.currency_code = v_currency
        )
      )
    ORDER BY option.confidence_score DESC, option.id
    LIMIT v_page_size
  )
  SELECT jsonb_build_object(
    'data', COALESCE(jsonb_agg(jsonb_build_object(
      'from', origin_airport_iata,
      'to', destination_airport_iata,
      'airline', provider_airline_iata,
      'evidence_type', evidence_type,
      'route_path', route_path,
      'observation', CASE WHEN observed_amount IS NULL THEN NULL ELSE jsonb_build_object(
        'observed_amount', observed_amount,
        'currency_code', currency_code,
        'valid_until', observation_valid_until
      ) END
    ) ORDER BY confidence_score DESC, id), '[]'::JSONB),
    'meta', jsonb_build_object(
      'data_version', 'v_' || md5(v_version_id::TEXT),
      'page_size', v_page_size
    ),
    'error', NULL
  ) INTO v_result FROM filtered;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_routes(JSONB) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_search_routes(JSONB) TO service_role;
