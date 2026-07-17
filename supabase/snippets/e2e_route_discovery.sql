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

SELECT public.refresh_route_options();

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{"from":"SGN","to":"LHR"}'::JSONB)
    #>> '{meta,total}' = '3',
  'end-to-end search returns direct and one-stop options'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{"from":"SGN","to":"LHR","airlines":["SQ"]}'::JSONB)
    #>> '{meta,total}' = '1',
  'end-to-end airline filter returns one option'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{"from":"SGN","to":"LHR","exclude_airports":["SIN"]}'::JSONB)
    #>> '{meta,total}' = '2',
  'end-to-end connection exclusion removes the one-stop option'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_search_routes('{"from":"SGN","to":"LHR"}'::JSONB)
      #> '{meta,facets,airlines}'
  ) = 2,
  'end-to-end response returns airline facets'
);

ROLLBACK;
