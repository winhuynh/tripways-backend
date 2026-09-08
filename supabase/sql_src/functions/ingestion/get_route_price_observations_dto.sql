-- ============================================================================
-- Function: admin.get_route_price_observations_dto
-- Purpose: Load canonical published price observations DTO for an origin/destination route.
-- Responsibilities: Query public.flight_route_prices and format sorted JSONB observation array.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.get_route_price_observations_dto(
  p_origin_iata TEXT,
  p_destination_iata TEXT,
  p_currency_code TEXT,
  p_market_code TEXT
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'observation_ref', p.public_reference,
      'observed_amount', p.observed_amount,
      'currency_code', p.currency_code,
      'departure_date', p.departure_date,
      'direct', p.direct,
      'transfer_count', p.transfer_count,
      'duration_minutes', p.duration_minutes,
      'observed_at', p.observed_at,
      'valid_until', p.valid_until
    ) ORDER BY p.observed_amount ASC NULLS LAST
  ), '[]'::JSONB)
  FROM public.flight_route_prices AS p
  JOIN public.airports AS oa ON oa.id = p.origin_airport_id AND oa.iata = upper(trim(p_origin_iata))
  LEFT JOIN public.airports AS da ON da.id = p.destination_airport_id AND da.iata = CASE WHEN p_destination_iata IS NOT NULL AND length(trim(p_destination_iata)) > 0 THEN upper(trim(p_destination_iata)) ELSE NULL END
  WHERE p.status = 'published'
    AND p.valid_until > now()
    AND p.currency_code = upper(trim(coalesce(p_currency_code, 'USD')))
    AND p.market_code = lower(trim(coalesce(p_market_code, 'us')))
    AND (p_destination_iata IS NULL OR length(trim(p_destination_iata)) = 0 OR da.id IS NOT NULL);
$$;

REVOKE ALL ON FUNCTION admin.get_route_price_observations_dto(TEXT, TEXT, TEXT, TEXT)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.get_route_price_observations_dto(TEXT, TEXT, TEXT, TEXT) TO service_role;
