-- Build a disposable route-search projection from provider-neutral route evidence.
CREATE OR REPLACE FUNCTION private.refresh_route_search_options(p_publication_version_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
VOLATILE
SET search_path = ''
AS $$
DECLARE v_count INTEGER;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.publication_versions v
    WHERE v.id = p_publication_version_id AND v.status = 'building'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_PUBLICATION_VERSION_INVALID';
  END IF;

  DELETE FROM public.flight_route_options WHERE publication_version_id = p_publication_version_id;

  INSERT INTO public.flight_route_options (
    id, publication_version_id,
    origin_city_id, origin_city_slug, origin_country_code,
    destination_city_id, destination_city_slug, destination_country_code,
    origin_airport_id, origin_airport_iata,
    destination_airport_id, destination_airport_iata,
    canonical_airline_id, provider_airline_iata, evidence_type, confidence_score,
    observed_amount, currency_code, observation_valid_until, route_path
  )
  SELECT
    route.id, p_publication_version_id,
    origin_city.id, origin_city.slug, origin_country.iso2,
    destination_city.id, destination_city.slug, destination_country.iso2,
    origin_airport.id, origin_airport.iata,
    destination_airport.id, destination_airport.iata,
    route.canonical_airline_id, route.provider_airline_iata, route.evidence_type, route.confidence_score,
    observation.observed_amount, observation.currency_code, observation.valid_until,
    registry.canonical_path
  FROM public.flight_routes route
  JOIN public.airports origin_airport ON origin_airport.id = route.origin_airport_id
  JOIN public.cities origin_city ON origin_city.id = origin_airport.city_id
  JOIN public.countries origin_country ON origin_country.id = origin_city.country_id
  JOIN public.airports destination_airport ON destination_airport.id = route.destination_airport_id
  JOIN public.cities destination_city ON destination_city.id = destination_airport.city_id
  JOIN public.countries destination_country ON destination_country.id = destination_city.country_id
  JOIN admin.data_sources source ON source.id = route.source_id
  LEFT JOIN public.route_pages page
    ON page.origin_city_id = origin_city.id
   AND page.destination_city_id = destination_city.id
   AND page.locale = 'en-GB'
  LEFT JOIN public.pseo_pages registry ON registry.id = page.pseo_page_id AND registry.status <> 'archived'
  LEFT JOIN LATERAL (
    SELECT item.observed_amount, item.currency_code, item.valid_until
    FROM public.flight_content_observations item
    JOIN admin.data_sources observation_source ON observation_source.id = item.source_id
    WHERE item.origin_city_id = origin_city.id
      AND item.destination_city_id = destination_city.id
      AND item.status = 'published'
      AND item.valid_until > now()
      AND item.observed_amount IS NOT NULL
      AND observation_source.production_display_allowed
    ORDER BY item.observed_at DESC, item.id
    LIMIT 1
  ) observation ON TRUE
  WHERE route.status IN ('verified_active', 'likely_active', 'seasonal')
    AND (route.valid_until IS NULL OR route.valid_until > now())
    AND origin_airport.status = 'active'
    AND destination_airport.status = 'active'
    AND origin_city.id <> destination_city.id
    AND (source.derived_data_allowed OR source.source_type = 'development_fixture');

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
