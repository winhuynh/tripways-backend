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
  jsonb_array_length(
    public.rpc_search_route_options_v2(
      '{"scope":{"type":"origin_city","key":"bangkok"},"filters":{"max_stops":3},"page_size":100}'::JSONB
    )->'data'
  ) > 0,
  'origin city scope returns routes'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(
      public.rpc_search_route_options_v2(
        '{"scope":{"type":"global"},"filters":{"max_stops":1},"page_size":100}'::JSONB
      )->'data'
    ) item
    WHERE (item->>'stops')::INTEGER > 1
  ),
  'max stops is shared by every scope'
);

SELECT pg_temp.test_assert(
  public.rpc_search_route_options_v2(
    '{"scope":{"type":"global"},"filters":{"max_stops":3,"unexpected":true},"page_size":20}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'SQL boundary rejects unknown filter fields'
);

SELECT pg_temp.test_assert(
  public.rpc_search_route_options_v2(
    '{"scope":{"type":"global"},"filters":{"max_stops":3,"cabin":"invalid"},"page_size":20}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'SQL boundary rejects invalid cabins'
);

ROLLBACK;
