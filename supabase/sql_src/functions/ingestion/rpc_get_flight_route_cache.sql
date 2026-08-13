-- ============================================================================
-- Function: public.rpc_get_flight_route_cache
-- Purpose: Read one bounded, public-safe on-demand flight cache scope.
-- Responsibilities: Enforce freshness and return an explicit cache state without internal IDs.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_flight_route_cache(p_input JSONB)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  WITH identity AS (
    SELECT
      upper(p_input->>'origin') AS origin_iata,
      NULLIF(upper(p_input->>'destination'), '') AS destination_iata,
      lower(p_input->>'market') AS market_code,
      upper(p_input->>'currency') AS currency_code,
      p_input->>'locale' AS locale,
      'frc_' || md5(
        upper(p_input->>'origin') || '|' ||
        COALESCE(NULLIF(upper(p_input->>'destination'), ''), '*') || '|' ||
        lower(p_input->>'market') || '|' ||
        upper(p_input->>'currency') || '|' ||
        (p_input->>'locale')
      ) AS cache_key
  ),
  state AS (
    SELECT cache.*
    FROM admin.flight_route_cache_states AS cache
    JOIN identity ON identity.cache_key = cache.cache_key
  ),
  routes AS (
    SELECT jsonb_agg(
      jsonb_build_object(
        'from', origin_airport.iata,
        'to', destination_airport.iata,
        'airline', price.provider_airline_iata,
        'direct', price.direct,
        'transferCount', price.transfer_count,
        'estimatedAmount', price.observed_amount,
        'currency', price.currency_code,
        'departureDate', price.departure_date,
        'returnDate', price.return_date,
        'observedAt', price.observed_at,
        'validUntil', price.valid_until,
        'observationRef', price.public_reference
      )
      ORDER BY price.observed_amount NULLS LAST, destination_airport.iata
    ) AS items,
    min(price.observed_at) AS observed_at,
    min(price.valid_until) AS valid_until
    FROM public.flight_route_prices AS price
    JOIN identity ON identity.cache_key = price.cache_key
    JOIN public.airports AS origin_airport ON origin_airport.id = price.origin_airport_id
    JOIN public.airports AS destination_airport ON destination_airport.id = price.destination_airport_id
    WHERE price.status = 'published'
      AND price.valid_until > now()
  )
  SELECT jsonb_build_object(
    'data', jsonb_build_object(
      'status', CASE
        WHEN routes.items IS NOT NULL THEN 'available'
        WHEN state.status IN ('empty', 'failed') AND state.next_refresh_at > now() THEN 'unavailable'
        ELSE 'loading'
      END,
      'origin', identity.origin_iata,
      'destination', identity.destination_iata,
      'routes', COALESCE(routes.items, '[]'::JSONB)
    ),
    'meta', jsonb_build_object(
      'cache', CASE WHEN routes.items IS NULL THEN 'miss' ELSE 'hit' END,
      'observedAt', routes.observed_at,
      'validUntil', routes.valid_until
    ),
    'error', NULL
  )
  FROM identity
  LEFT JOIN state ON TRUE
  LEFT JOIN routes ON TRUE;
$$;

REVOKE ALL ON FUNCTION public.rpc_get_flight_route_cache(JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_flight_route_cache(JSONB) TO service_role;
