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
  jsonb_array_length(public.rpc_search_routes(
    '{"scope":{"type":"origin_city","key":"ho-chi-minh-city"},"filters":{},"page_size":100}'::JSONB
  )->'data') > 0,
  'origin city scope returns routes'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes(
    '{"scope":{"type":"global"},"filters":{"currency":"USD","max_amount":100},"page_size":100}'::JSONB
  )->'data') = 1,
  'bounded price filters apply to the global scope'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes(
    '{"scope":{"type":"global"},"filters":{"unexpected":true},"page_size":20}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'SQL boundary rejects unknown filter fields'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes(
    '{"scope":{"type":"global"},"filters":{"currency":"INVALID"},"page_size":20}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'SQL boundary rejects invalid currencies'
);

ROLLBACK;
