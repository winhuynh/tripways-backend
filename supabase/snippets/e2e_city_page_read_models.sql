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
  jsonb_array_length(public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #> '{data,routes}') = 2,
  'Ho Chi Minh City page exposes both seeded routes'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #>> '{data,routes,0,from}' = 'SGN',
  'Ho Chi Minh City routes expose the public origin code'
);

SELECT pg_temp.test_assert(
  (public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #>> '{data,routes,0,observed_amount}')::NUMERIC > 0,
  'Ho Chi Minh City page exposes a fresh estimated route price'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #>> '{data,content,seo,h1}' = 'Flights from Ho Chi Minh City',
  'Ho Chi Minh City page exposes reviewed aggregate content'
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
