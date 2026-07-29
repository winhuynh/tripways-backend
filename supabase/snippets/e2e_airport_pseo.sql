\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(
  p_condition BOOLEAN,
  p_message TEXT
)
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
  to_regclass('public.airport_pages') IS NOT NULL,
  'airport page schema exists'
);

SELECT pg_temp.test_assert(
  to_regprocedure('public.rpc_get_airport_page(jsonb)') IS NOT NULL,
  'airport page RPC exists'
);

SELECT pg_temp.test_assert(
  to_regprocedure('public.rpc_search_airport_direct_routes(jsonb)') IS NOT NULL,
  'airport direct-route search RPC exists'
);

SELECT pg_temp.test_assert(
  to_regprocedure('public.refresh_pseo_read_models()') IS NOT NULL,
  'one shared pSEO refresh function exists'
);

SELECT public.refresh_pseo_read_models();

SELECT pg_temp.test_assert(
  public.rpc_get_airport_page(
    '{"airport_iata":"bkk","locale":"en-GB"}'::JSONB
  ) #>> '{data,airport,iata}' = 'BKK',
  'airport page normalizes IATA and returns airport identity'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_airport_page(
      '{"airport_iata":"BKK","locale":"en-GB"}'::JSONB
    ) #> '{data,featured_outbound_routes}'
  ) >= 2,
  'airport page returns featured outbound routes'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_airport_page(
      '{"airport_iata":"BKK","locale":"en-GB"}'::JSONB
    ) #> '{data,featured_inbound_routes}'
  ) >= 1,
  'airport page returns featured inbound routes'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_airport_page(
      '{"airport_iata":"BKK","locale":"en-GB"}'::JSONB
    ) #> '{data,access_options}'
  ) = 1,
  'airport page returns published access content'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_airport_page(
      '{"airport_iata":"BKK","locale":"en-GB"}'::JSONB
    ) #> '{data,lounges}'
  ) = 1,
  'airport page returns published lounge content'
);

SELECT pg_temp.test_assert(
  public.rpc_get_airport_page(
    '{"airport_iata":"BKK","locale":"en-GB"}'::JSONB
  ) #>> '{meta,noindex_reason}' = 'development_fixture',
  'development route sources keep the airport page noindex'
);

SELECT pg_temp.test_assert(
  (
    public.rpc_search_airport_direct_routes(
      '{"airport_iata":"BKK","direction":"outbound","countries":["SG"]}'::JSONB
    ) #>> '{meta,total}'
  )::INTEGER >= 1,
  'outbound route search filters by destination country'
);

SELECT pg_temp.test_assert(
  (
    public.rpc_search_airport_direct_routes(
      '{"airport_iata":"BKK","direction":"inbound"}'::JSONB
    ) #>> '{meta,total}'
  )::INTEGER >= 1,
  'inbound route search reads routes arriving at the airport'
);

SELECT pg_temp.test_assert(
  public.rpc_search_airport_direct_routes(
    '{"airport_iata":"BKK","direction":"sideways"}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'route search rejects an invalid direction'
);

SELECT pg_temp.test_assert(
  public.rpc_get_airport_page(
    '{"airport_iata":"INVALID"}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'airport page rejects an invalid IATA code'
);

SELECT pg_temp.test_assert(
  public.rpc_get_airport_page(
    '{"airport_iata":"DMK","locale":"en-GB"}'::JSONB
  ) #>> '{data,airport,iata}' = 'DMK',
  'DMK airport preview resolves'
);

SELECT pg_temp.test_assert(
  public.rpc_get_airport_page(
    '{"airport_iata":"SIN","locale":"en-GB"}'::JSONB
  ) #>> '{data,airport,iata}' = 'SIN',
  'SIN airport preview resolves'
);

SELECT pg_temp.test_assert(
  (
    public.rpc_search_airport_direct_routes(
      '{"airport_iata":"DMK","direction":"inbound"}'::JSONB
    ) #>> '{meta,total}'
  )::INTEGER >= 1,
  'DMK preview has inbound route coverage'
);

SELECT pg_temp.test_assert(
  (
    public.rpc_search_airport_direct_routes(
      '{"airport_iata":"SIN","direction":"outbound"}'::JSONB
    ) #>> '{meta,total}'
  )::INTEGER >= 1,
  'SIN preview has outbound route coverage'
);

SELECT pg_temp.test_assert(
  NOT has_function_privilege(
    'anon',
    'public.rpc_get_airport_page(jsonb)',
    'EXECUTE'
  ),
  'anon cannot execute the airport page RPC'
);

SELECT pg_temp.test_assert(
  NOT has_function_privilege(
    'authenticated',
    'public.rpc_search_airport_direct_routes(jsonb)',
    'EXECUTE'
  ),
  'authenticated clients cannot execute airport route search'
);

ROLLBACK;
