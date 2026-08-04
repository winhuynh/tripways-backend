BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(p_condition BOOLEAN, p_message TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT COALESCE(p_condition, FALSE) THEN
    RAISE EXCEPTION 'ASSERTION FAILED: %', p_message;
  END IF;
END;
$$;

SELECT pg_temp.test_assert(
  public.rpc_resolve_homepage_origin(
    '{"latitude":13.69,"longitude":100.75}'::JSONB
  ) #>> '{data,airport,iata}' = 'BKK',
  'valid visitor coordinates resolve the nearest route-capable airport'
);

SELECT pg_temp.test_assert(
  public.rpc_resolve_homepage_origin('{}'::JSONB)
    #>> '{data,airport,iata}' = 'JFK',
  'missing visitor coordinates fall back to JFK'
);

SELECT pg_temp.test_assert(
  public.rpc_resolve_homepage_origin(
    '{"latitude":91,"longitude":100.75}'::JSONB
  ) #>> '{data,airport,iata}' = 'JFK',
  'out-of-range visitor coordinates fall back to JFK'
);

SELECT pg_temp.test_assert(
  public.rpc_resolve_homepage_origin('{}'::JSONB)
    #>> '{meta,resolution}' = 'fallback',
  'fallback resolution is explicit in response metadata'
);

ROLLBACK;
