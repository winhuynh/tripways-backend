\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(p_condition BOOLEAN, p_message TEXT)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT COALESCE(p_condition, FALSE) THEN
    RAISE EXCEPTION 'ASSERTION FAILED: %', p_message;
  END IF;
END;
$$;

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #>> '{data,city,slug}' = 'ho-chi-minh-city',
  'Ho Chi Minh City page resolves through the canonical page RPC'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #> '{data,routes}') = 8,
  'Ho Chi Minh City page exposes the deterministic route matrix'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #>> '{data,routes,0,from}' = 'SGN',
  'Ho Chi Minh City routes expose the public origin code'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(
      public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #> '{data,routes}'
    ) AS route
    LEFT JOIN public.pseo_pages AS page
      ON page.canonical_path = route->>'route_path'
      AND page.status = 'published'
    WHERE page.id IS NULL
  ),
  'Ho Chi Minh City page emits only published route links'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #>> '{data,page,h1}' = 'Direct Flights from Ho Chi Minh City (SGN)',
  'Ho Chi Minh City page exposes reviewed aggregate content'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(
      public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB) #> '{data,featured_destinations}'
    ) AS destination
    WHERE (destination->>'stops')::INTEGER <> 0
  ),
  'direct-flight city pages do not expose connecting itineraries as featured destinations'
);

SELECT pg_temp.test_assert(
  EXISTS (
    SELECT 1
    FROM jsonb_array_elements(
      public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB) #> '{data,featured_destinations}'
    ) AS destination
    WHERE destination->'destination_airports' @> '["NRT"]'::JSONB
      AND destination #>> '{fare_estimate,min}' = '190.00'
      AND destination #>> '{fare_estimate,currency}' = 'USD'
  ),
  'city destinations expose deterministic fare observations for fare-filter testing'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"missing","locale":"en-GB"}'::JSONB) #>> '{error,code}' = 'ERR_PAGE_NOT_FOUND',
  'missing city returns the canonical not-found error'
);

SELECT pg_temp.test_assert(
  NOT has_function_privilege('anon', 'public.rpc_get_page(jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'public.rpc_get_page(jsonb)', 'EXECUTE'),
  'page RPC remains service-role only'
);

ROLLBACK;
