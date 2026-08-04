-- Publish one provider-neutral price-estimate batch after source-rights validation.
CREATE OR REPLACE FUNCTION private.publish_price_estimate_batch(
  p_source_code TEXT, p_idempotency_key TEXT, p_checksum TEXT,
  p_provider_version TEXT, p_source_time TIMESTAMPTZ, p_estimates JSONB
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_source admin.data_sources%ROWTYPE;
  v_batch_id UUID;
  v_estimate JSONB;
  v_origin_city UUID;
  v_destination_city UUID;
  v_origin_airport UUID;
  v_destination_airport UUID;
  v_airline UUID;
  v_count INTEGER := 0;
BEGIN
  IF p_provider_version <> 'route-price-estimates.v1'
    OR p_checksum !~ '^[a-f0-9]{64}$'
    OR char_length(p_idempotency_key) NOT BETWEEN 8 AND 128
    OR jsonb_typeof(p_estimates) <> 'array'
    OR jsonb_array_length(p_estimates) > 1000
  THEN RETURN jsonb_build_object('status','failed','acceptedCount',0,'rejectedCount',0,'errorCode','ERR_INGESTION_INVALID_REQUEST'); END IF;

  SELECT * INTO v_source FROM admin.data_sources s WHERE s.code = p_source_code;
  IF v_source.id IS NULL OR NOT v_source.storage_allowed OR NOT v_source.derived_data_allowed
    OR NOT v_source.production_display_allowed
    OR (v_source.rights_effective_at IS NOT NULL AND now() NOT BETWEEN v_source.rights_effective_at AND v_source.rights_expires_at)
  THEN RETURN jsonb_build_object('status','failed','acceptedCount',0,'rejectedCount',jsonb_array_length(p_estimates),'errorCode','ERR_INGESTION_SOURCE_NOT_ALLOWED'); END IF;

  SELECT id INTO v_batch_id FROM private.raw_import_batches
  WHERE source_id = v_source.id AND (checksum = p_checksum OR idempotency_key = p_idempotency_key) LIMIT 1;
  IF v_batch_id IS NOT NULL THEN
    RETURN jsonb_build_object('status','published','acceptedCount',0,'rejectedCount',0,'errorCode','ERR_INGESTION_BATCH_DUPLICATE','batchId',v_batch_id);
  END IF;

  INSERT INTO private.raw_import_batches(source_id,provider_version,checksum,idempotency_key,source_time,status)
  VALUES(v_source.id,p_provider_version,p_checksum,p_idempotency_key,p_source_time,'validated') RETURNING id INTO v_batch_id;

  FOR v_estimate IN SELECT value FROM jsonb_array_elements(p_estimates) LOOP
    IF NULLIF(btrim(v_estimate->>'sourceId'),'') IS NULL
      OR (v_estimate->>'priceMin')::NUMERIC < 0
      OR (v_estimate->>'priceMax')::NUMERIC < (v_estimate->>'priceMin')::NUMERIC
      OR v_estimate->>'currencyCode' !~ '^[A-Z]{3}$'
      OR (v_estimate->>'validUntil')::TIMESTAMPTZ <= (v_estimate->>'lastVerifiedAt')::TIMESTAMPTZ
    THEN RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='ERR_INGESTION_VALIDATION_FAILED'; END IF;

    SELECT id INTO v_origin_city FROM public.cities WHERE source_record_id = v_estimate->>'originCitySourceId';
    SELECT id INTO v_destination_city FROM public.cities WHERE source_record_id = v_estimate->>'destinationCitySourceId';
    SELECT id INTO v_origin_airport FROM public.airports WHERE iata = NULLIF(v_estimate->>'originAirportIata','');
    SELECT id INTO v_destination_airport FROM public.airports WHERE iata = NULLIF(v_estimate->>'destinationAirportIata','');
    SELECT id INTO v_airline FROM public.airlines WHERE iata = NULLIF(v_estimate->>'airlineIata','');
    IF v_origin_city IS NULL OR v_destination_city IS NULL THEN RAISE EXCEPTION USING ERRCODE='23503', MESSAGE='ERR_INGESTION_UNRESOLVED_REFERENCE'; END IF;

    INSERT INTO private.raw_base_data_records(batch_id,record_type,source_key,payload,validation_state)
    VALUES(v_batch_id,'route_price_estimate',v_estimate->>'sourceId',v_estimate,'valid');
    INSERT INTO public.route_price_estimates(
      origin_city_id,destination_city_id,origin_airport_id,destination_airport_id,airline_id,
      trip_type,cabin,stop_bucket,baggage_included,price_min,price_max,currency_code,
      estimate_method,sample_window_start,sample_window_end,sample_count,source_id,source_record_id,
      confidence_score,last_verified_at,valid_until,status,data_version
    ) VALUES(
      v_origin_city,v_destination_city,v_origin_airport,v_destination_airport,v_airline,
      v_estimate->>'tripType',v_estimate->>'cabin',v_estimate->>'stopBucket',(v_estimate->>'baggageIncluded')::BOOLEAN,
      (v_estimate->>'priceMin')::NUMERIC,(v_estimate->>'priceMax')::NUMERIC,v_estimate->>'currencyCode',
      v_estimate->>'estimateMethod',(v_estimate->>'sampleWindowStart')::DATE,(v_estimate->>'sampleWindowEnd')::DATE,
      (v_estimate->>'sampleCount')::INTEGER,v_source.id,v_estimate->>'sourceId',(v_estimate->>'confidenceScore')::NUMERIC,
      (v_estimate->>'lastVerifiedAt')::TIMESTAMPTZ,(v_estimate->>'validUntil')::TIMESTAMPTZ,'published',v_batch_id
    ) ON CONFLICT(source_id,source_record_id) DO UPDATE SET
      price_min=excluded.price_min,price_max=excluded.price_max,currency_code=excluded.currency_code,
      confidence_score=excluded.confidence_score,last_verified_at=excluded.last_verified_at,
      valid_until=excluded.valid_until,status='published',data_version=excluded.data_version,updated_at=now();
    v_count := v_count + 1;
  END LOOP;
  UPDATE private.raw_import_batches SET status='published',updated_at=now() WHERE id=v_batch_id;
  RETURN jsonb_build_object('status','published','acceptedCount',v_count,'rejectedCount',0,'errorCode',NULL,'batchId',v_batch_id);
END;
$$;
REVOKE ALL ON FUNCTION private.publish_price_estimate_batch(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,JSONB) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION private.publish_price_estimate_batch(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,JSONB) TO service_role;

CREATE OR REPLACE FUNCTION public.rpc_publish_price_estimate_batch(
  p_source_code TEXT,p_idempotency_key TEXT,p_checksum TEXT,p_provider_version TEXT,p_source_time TIMESTAMPTZ,p_estimates JSONB
) RETURNS JSONB LANGUAGE sql SET search_path='' AS $$
SELECT private.publish_price_estimate_batch(p_source_code,p_idempotency_key,p_checksum,p_provider_version,p_source_time,p_estimates);
$$;
REVOKE ALL ON FUNCTION public.rpc_publish_price_estimate_batch(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,JSONB) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_publish_price_estimate_batch(TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,JSONB) TO service_role;
