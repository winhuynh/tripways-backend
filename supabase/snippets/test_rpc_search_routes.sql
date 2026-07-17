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
  public.rpc_search_routes('{"from":"sgn","to":"LHR","max_stops":1}'::JSONB)
    #>> '{meta,total}' = '3',
  'search normalizes IATA and returns three SGN to LHR options'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{"from":"SGN","to":"LHR","max_stops":0}'::JSONB)
    #>> '{meta,total}' = '2',
  'direct-only filter returns two schedules'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{"from":"SGN","to":"LHR","airlines":["SQ"]}'::JSONB)
    #>> '{meta,total}' = '1',
  'airline filter finds the Singapore Airlines connection'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{"from":"SGN","to":"LHR","exclude_airports":["SIN"]}'::JSONB)
    #>> '{meta,total}' = '2',
  'connection exclusion removes the one-stop option'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{"from":"SGN","to":"LHR","max_duration_minutes":1000}'::JSONB)
    #>> '{meta,total}' = '2',
  'duration filter removes the slower connection'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{"from":"SGN","to":"SGN"}'::JSONB)
    #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'same origin and destination returns a stable validation error'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_search_routes('{"from":"SGN","to":"LHR"}'::JSONB)
      #> '{meta,facets,stops}'
  ) = 2,
  'response includes stop-count facets'
);

ROLLBACK;
