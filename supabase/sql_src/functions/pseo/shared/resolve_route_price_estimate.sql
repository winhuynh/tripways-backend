-- Resolve a display-safe estimate or an explicit null-state. Never substitutes zero.
CREATE OR REPLACE FUNCTION public.resolve_route_price_estimate(
  p_origin_city_id UUID,p_destination_city_id UUID,p_cabin TEXT DEFAULT 'any',p_stop_bucket TEXT DEFAULT 'any'
) RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE v_row RECORD; v_any RECORD;
BEGIN
  SELECT estimate.*,source.production_display_allowed,source.derived_data_allowed,
    source.rights_effective_at,source.rights_expires_at,source.attribution_text,source.attribution_url
  INTO v_any FROM public.flight_content_observations estimate
  JOIN admin.data_sources source ON source.id=estimate.source_id
  WHERE estimate.origin_city_id=p_origin_city_id AND estimate.destination_city_id=p_destination_city_id
  ORDER BY estimate.observed_at DESC LIMIT 1;
  IF v_any.id IS NULL THEN RETURN jsonb_build_object('state','unavailable','reason','missing','estimate',NULL); END IF;
  IF NOT v_any.production_display_allowed OR NOT v_any.derived_data_allowed
    OR (v_any.rights_effective_at IS NOT NULL AND now() NOT BETWEEN v_any.rights_effective_at AND v_any.rights_expires_at)
  THEN RETURN jsonb_build_object('state','unavailable','reason','unlicensed','estimate',NULL); END IF;
  IF v_any.status <> 'published' OR v_any.valid_until <= now()
  THEN RETURN jsonb_build_object('state','unavailable','reason','expired','estimate',NULL); END IF;
  v_row := v_any;
  RETURN jsonb_build_object('state','available','reason',NULL,'observation',jsonb_build_object(
    'observed_amount',v_row.observed_amount,'currency_code',v_row.currency_code,
    'trip_type',v_row.trip_type,'direct',v_row.direct,'transfer_count',v_row.transfer_count,
    'departure_date',v_row.departure_date,'return_date',v_row.return_date,
    'observed_at',v_row.observed_at,'valid_until',v_row.valid_until,
    'disclaimer','Cached affiliate fare observed earlier; availability and final price are confirmed by the booking partner.',
    'attribution_text',v_row.attribution_text,'attribution_url',v_row.attribution_url
  ));
END;
$$;
REVOKE ALL ON FUNCTION public.resolve_route_price_estimate(UUID,UUID,TEXT,TEXT) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_route_price_estimate(UUID,UUID,TEXT,TEXT) TO service_role;
