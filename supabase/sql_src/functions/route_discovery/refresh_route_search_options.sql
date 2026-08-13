-- ============================================================================
-- Function: admin.refresh_route_search_options
-- Purpose: Build a disposable route-search projection from fresh route prices.
-- Responsibilities: Materialize one complete candidate publication version.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.refresh_route_search_options(p_publication_version_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
VOLATILE
SET search_path = ''
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.publication_versions AS version
    WHERE version.id = p_publication_version_id
      AND version.status = 'building'
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
  SELECT DISTINCT ON (
    price.origin_airport_id,
    price.destination_airport_id,
    price.provider_airline_iata
  )
    price.id, p_publication_version_id,
    origin_city.id, origin_city.slug, origin_country.iso2,
    destination_city.id, destination_city.slug, destination_country.iso2,
    origin_airport.id, origin_airport.iata,
    destination_airport.id, destination_airport.iata,
    price.canonical_airline_id, price.provider_airline_iata, 'content_observation', 1.000,
    price.observed_amount, price.currency_code, price.valid_until,
    registry.canonical_path
  FROM public.flight_route_prices price
  JOIN public.airports origin_airport ON origin_airport.id = price.origin_airport_id
  JOIN public.cities origin_city ON origin_city.id = origin_airport.city_id
  JOIN public.countries origin_country ON origin_country.id = origin_city.country_id
  JOIN public.airports destination_airport ON destination_airport.id = price.destination_airport_id
  JOIN public.cities destination_city ON destination_city.id = destination_airport.city_id
  JOIN public.countries destination_country ON destination_country.id = destination_city.country_id
  JOIN admin.data_sources source ON source.id = price.source_id
  LEFT JOIN public.route_pages page
    ON page.origin_city_id = origin_city.id
   AND page.destination_city_id = destination_city.id
   AND page.locale = 'en-GB'
  LEFT JOIN public.pseo_pages registry ON registry.id = page.pseo_page_id AND registry.status <> 'archived'
  WHERE price.status = 'published'
    AND price.valid_until > now()
    AND price.observed_amount IS NOT NULL
    AND price.origin_airport_id IS NOT NULL
    AND price.destination_airport_id IS NOT NULL
    AND origin_airport.status = 'active'
    AND destination_airport.status = 'active'
    AND origin_city.id <> destination_city.id
    AND (source.production_display_allowed OR source.source_type = 'development_fixture')
  ORDER BY
    price.origin_airport_id,
    price.destination_airport_id,
    price.provider_airline_iata,
    price.observed_amount,
    price.observed_at DESC,
    price.id;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION admin.refresh_route_search_options(UUID)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.refresh_route_search_options(UUID) TO service_role;
