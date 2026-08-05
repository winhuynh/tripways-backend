CREATE OR REPLACE FUNCTION private.build_homepage_discovery(p_input JSONB)
RETURNS JSONB LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE
  v_origin TEXT:=upper(btrim(COALESCE(p_input->>'origin','')));
  v_max_stops INTEGER:=COALESCE((p_input->>'max_stops')::INTEGER,3);
  v_max_duration INTEGER:=NULLIF(p_input->>'max_duration_minutes','')::INTEGER;
  v_price_max NUMERIC:=NULLIF(p_input->>'price_max','')::NUMERIC;
  v_currency TEXT:=upper(NULLIF(btrim(COALESCE(p_input->>'currency','')),''));
  v_limit INTEGER:=COALESCE((p_input->>'limit')::INTEGER,20);
  v_offset INTEGER:=COALESCE((p_input->>'offset')::INTEGER,0);
  v_airlines TEXT[]:='{}';v_connections TEXT[]:='{}';v_origin_airports UUID[];
BEGIN
  IF v_max_stops NOT BETWEEN 0 AND 3 OR v_limit NOT BETWEEN 1 AND 100 OR v_offset NOT BETWEEN 0 AND 10000
    OR v_max_duration IS NOT NULL AND v_max_duration<1 OR v_price_max IS NOT NULL AND v_price_max<0
    OR v_currency IS NOT NULL AND v_currency!~'^[A-Z]{3}$'
  THEN RETURN private.build_rpc_error(NULL,'ERR_INVALID_REQUEST','Invalid homepage discovery filters.');END IF;
  IF p_input?'airlines' THEN SELECT COALESCE(array_agg(upper(value)),'{}') INTO v_airlines FROM jsonb_array_elements_text(p_input->'airlines');END IF;
  IF p_input?'connection_airports' THEN SELECT COALESCE(array_agg(upper(value)),'{}') INTO v_connections FROM jsonb_array_elements_text(p_input->'connection_airports');END IF;
  IF EXISTS(SELECT 1 FROM unnest(v_airlines) x WHERE x!~'^[A-Z0-9]{2}$') OR EXISTS(SELECT 1 FROM unnest(v_connections) x WHERE x!~'^[A-Z0-9]{3}$') THEN RETURN private.build_rpc_error(NULL,'ERR_INVALID_REQUEST','Invalid code filter.');END IF;
  SELECT array_agg(DISTINCT airport.id) INTO v_origin_airports FROM public.airports airport
  LEFT JOIN public.cities city ON city.id=airport.city_id LEFT JOIN public.metro_area_airports mapping ON mapping.airport_id=airport.id LEFT JOIN public.metro_areas metro ON metro.id=mapping.metro_area_id
  WHERE airport.iata=v_origin OR upper(city.slug)=v_origin OR metro.code=v_origin;
  RETURN jsonb_build_object('data',jsonb_build_object(
    'featured_origins',(SELECT COALESCE(jsonb_agg(to_jsonb(item)),'[]') FROM(SELECT city.name,city.slug,count(option.id)::INTEGER route_option_count FROM public.cities city JOIN public.airports airport ON airport.city_id=city.id JOIN public.route_options option ON option.origin_airport_id=airport.id GROUP BY city.id ORDER BY count(option.id) DESC,city.name LIMIT 12)item),
    'route_map',COALESCE((SELECT jsonb_agg(payload ORDER BY stop_count,total_duration_minutes) FROM(
      SELECT option.stop_count,option.total_duration_minutes,jsonb_build_object('route_option_id',option.id,'from',origin.iata,'to',destination.iata,'stops',option.stop_count,'duration_minutes',option.total_duration_minutes,
        'connection_airports',(SELECT COALESCE(jsonb_agg(airport.iata ORDER BY leg.ordinality),'[]') FROM unnest(option.connection_airport_ids) WITH ORDINALITY leg(id,ordinality) JOIN public.airports airport ON airport.id=leg.id),
        'route_path',format('/flights/%s-to-%s',origin_city.slug,destination_city.slug),
        'price',public.resolve_route_price_estimate(origin_city.id,destination_city.id,'any',CASE option.stop_count WHEN 0 THEN 'direct' WHEN 1 THEN 'one_stop' WHEN 2 THEN 'two_stops' ELSE 'three_stops' END)) payload
      FROM public.route_options option JOIN public.airports origin ON origin.id=option.origin_airport_id JOIN public.cities origin_city ON origin_city.id=origin.city_id JOIN public.airports destination ON destination.id=option.destination_airport_id JOIN public.cities destination_city ON destination_city.id=destination.city_id
      WHERE (v_origin_airports IS NULL OR option.origin_airport_id=ANY(v_origin_airports)) AND option.stop_count<=v_max_stops
        AND (v_max_duration IS NULL OR option.total_duration_minutes<=v_max_duration)
        AND (cardinality(v_airlines)=0 OR EXISTS(SELECT 1 FROM unnest(option.operating_airline_ids) leg_id(id) JOIN public.airlines airline ON airline.id=leg_id.id WHERE airline.iata=ANY(v_airlines)))
        AND (cardinality(v_connections)=0 OR EXISTS(SELECT 1 FROM unnest(option.connection_airport_ids) connection_id(id) JOIN public.airports airport ON airport.id=connection_id.id WHERE airport.iata=ANY(v_connections)))
        AND (v_price_max IS NULL OR EXISTS(SELECT 1 FROM public.route_price_estimates estimate JOIN admin.data_sources source ON source.id=estimate.source_id WHERE estimate.origin_city_id=origin_city.id AND estimate.destination_city_id=destination_city.id AND estimate.status='published' AND estimate.valid_until>now() AND source.production_display_allowed AND source.derived_data_allowed AND estimate.price_min<=v_price_max AND (v_currency IS NULL OR estimate.currency_code=v_currency)))
      ORDER BY option.stop_count,option.total_duration_minutes LIMIT v_limit OFFSET v_offset
    )filtered),'[]'),
    'nearby_airports',COALESCE((SELECT jsonb_agg(jsonb_build_object('iata',nearby.iata,'distance_km',mapping.distance_km)) FROM public.nearby_airports mapping JOIN public.airports nearby ON nearby.id=mapping.nearby_airport_id WHERE mapping.airport_id=ANY(COALESCE(v_origin_airports,'{}'))),'[]')),
    'meta',jsonb_build_object('data_version',(SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1),'max_supported_stops',3,'limit',v_limit,'offset',v_offset,'facets',jsonb_build_object(
      'stops',(SELECT COALESCE(jsonb_agg(to_jsonb(x)),'[]') FROM(SELECT stop_count value,count(*)::INTEGER count FROM public.route_options WHERE (v_origin_airports IS NULL OR origin_airport_id=ANY(v_origin_airports)) GROUP BY stop_count ORDER BY stop_count)x),
      'airlines',(SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.value),'[]') FROM(SELECT airline.iata value,count(*)::INTEGER count FROM public.route_options option CROSS JOIN LATERAL unnest(option.operating_airline_ids) leg_id(id) JOIN public.airlines airline ON airline.id=leg_id.id WHERE (v_origin_airports IS NULL OR option.origin_airport_id=ANY(v_origin_airports)) GROUP BY airline.iata)x),
      'connections',(SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.value),'[]') FROM(SELECT airport.iata value,count(*)::INTEGER count FROM public.route_options option CROSS JOIN LATERAL unnest(option.connection_airport_ids) connection_id(id) JOIN public.airports airport ON airport.id=connection_id.id WHERE (v_origin_airports IS NULL OR option.origin_airport_id=ANY(v_origin_airports)) GROUP BY airport.iata)x),
      'price',jsonb_build_object('currency',v_currency,'max',v_price_max,'missing_is_zero',FALSE))),'error',NULL);
END;$$;
REVOKE ALL ON FUNCTION private.build_homepage_discovery(JSONB) FROM public,anon,authenticated;GRANT EXECUTE ON FUNCTION private.build_homepage_discovery(JSONB) TO service_role;
