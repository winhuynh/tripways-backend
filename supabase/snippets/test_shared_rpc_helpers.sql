BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.test_assert(
  p_condition BOOLEAN,
  p_message TEXT
)
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
  private.normalize_airport_iata(' bkk ') = 'BKK',
  'airport IATA helper trims and normalizes valid input'
);

SELECT pg_temp.test_assert(
  private.normalize_airport_iata('invalid') IS NULL,
  'airport IATA helper rejects invalid input'
);

SELECT pg_temp.test_assert(
  private.normalize_airline_iata(' tg ') = 'TG',
  'airline IATA helper trims and normalizes valid input'
);

SELECT pg_temp.test_assert(
  private.build_rpc_error(
    '[]'::JSONB,
    'ERR_TEST',
    'Test error.'
  ) = '{
    "data": [],
    "meta": {},
    "error": {
      "code": "ERR_TEST",
      "message": "Test error."
    }
  }'::JSONB,
  'RPC error helper preserves the public envelope'
);

SELECT pg_temp.test_assert(
  private.parse_city_page_identity(
    '{"city_slug":" Bangkok ","locale":"en-GB"}'::JSONB
  ) #>> '{data,city_slug}' = 'bangkok',
  'city identity helper normalizes a valid slug'
);

SELECT pg_temp.test_assert(
  private.resolve_city_page_context('bangkok', 'en-GB')
    #>> '{data,city_id}' IS NOT NULL,
  'city context helper resolves the seeded Bangkok page'
);

SELECT pg_temp.test_assert(
  NOT has_function_privilege(
    'anon',
    'private.build_rpc_error(jsonb,text,text)',
    'EXECUTE'
  ),
  'anon cannot execute internal RPC helpers'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes('{}'::JSONB)
    #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'shared route search preserves its invalid identity contract'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{}'::JSONB)
    #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'city page preserves its invalid identity contract'
);

ROLLBACK;
