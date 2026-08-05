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
  public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB) #>> '{data,city,slug}' = 'bangkok',
  'Bangkok city page resolves through the canonical page RPC'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB) #> '{data,airports}') = 2,
  'Bangkok page exposes both seeded departure airports'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB) #> '{data,featured_destinations}') > 0,
  'Bangkok page exposes direct destinations'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB) #> '{data,price_summary}' IS NOT NULL,
  'Bangkok page exposes an explicit estimated-price state'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB) #> '{data,faqs}') = 4,
  'Bangkok page exposes page-specific FAQs'
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
