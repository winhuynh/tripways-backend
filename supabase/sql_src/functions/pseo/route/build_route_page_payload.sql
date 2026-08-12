CREATE OR REPLACE FUNCTION private.build_route_page_payload(p_input JSONB)
RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE
  v_locale TEXT := COALESCE(NULLIF(p_input->>'locale', ''), 'en-GB');
  v_page public.route_pages%ROWTYPE;
  v_registry public.pseo_pages%ROWTYPE;
  v_version UUID := (p_input->>'publication_version_id')::UUID;
BEGIN
  SELECT page.* INTO v_page
  FROM public.route_pages page
  JOIN public.pseo_pages registry ON registry.id = page.pseo_page_id
  WHERE registry.entity_key = lower(p_input->>'route_slug') AND page.locale = v_locale;
  IF v_page.id IS NULL THEN RETURN private.build_rpc_error(NULL, 'ERR_NOT_FOUND', 'Route page not found.'); END IF;
  SELECT * INTO v_registry FROM public.pseo_pages WHERE id = v_page.pseo_page_id;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'route', jsonb_build_object(
        'origin', (SELECT jsonb_build_object('id',id,'name',name,'slug',slug,'iata_code',iata_code) FROM public.cities WHERE id=v_page.origin_city_id),
        'destination', (SELECT jsonb_build_object('id',id,'name',name,'slug',slug,'iata_code',iata_code) FROM public.cities WHERE id=v_page.destination_city_id)
      ),
      'content', v_page.content,
      'route_options', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'from',origin_airport_iata,'to',destination_airport_iata,'airline',provider_airline_iata,
        'evidence_type',evidence_type,'confidence_score',confidence_score
      ) ORDER BY confidence_score DESC) FROM public.flight_route_options
        WHERE publication_version_id=v_version AND origin_city_id=v_page.origin_city_id AND destination_city_id=v_page.destination_city_id),'[]'::jsonb),
      'observations', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'observation_id',item.id,'observed_amount',item.observed_amount,'currency_code',item.currency_code,
        'departure_date',item.departure_date,'direct',item.direct,'valid_until',item.valid_until
      ) ORDER BY item.observed_amount NULLS LAST,item.observed_at DESC)
      FROM public.flight_content_observations item JOIN admin.data_sources source ON source.id=item.source_id
      WHERE item.origin_city_id=v_page.origin_city_id AND item.destination_city_id=v_page.destination_city_id
        AND item.status='published' AND item.valid_until>now() AND source.production_display_allowed),'[]'::jsonb),
      'disclosure', 'Cached observations are not live offers; final price and availability are confirmed by the booking partner.'
    ),
    'meta', jsonb_build_object('canonical_path',v_registry.canonical_path,'is_indexable',v_registry.is_indexable,
      'noindex_reason',v_registry.noindex_reason,'data_version',v_version,'source_freshness_at',v_registry.source_freshness_at),
    'error', NULL
  );
END; $$;
REVOKE ALL ON FUNCTION private.build_route_page_payload(JSONB) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.build_route_page_payload(JSONB) TO service_role;
