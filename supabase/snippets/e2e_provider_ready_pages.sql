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
  public.rpc_get_page('{"page_type":"homepage","entity_key":"homepage","locale":"en-GB"}'::JSONB) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'homepage is not a pSEO page contract'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB) #>> '{data,city,slug}' = 'ho-chi-minh-city',
  'city page exposes its canonical entity'
);

SELECT pg_temp.test_assert(
  NOT (public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB)->'data' ? 'featured_airlines'),
  'city does not expose a standalone airline section'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"airport","entity_key":"SGN","locale":"en-GB"}'::JSONB) #>> '{data,airport,iata}' = 'SGN'
  AND public.rpc_get_page('{"page_type":"airport","entity_key":"SGN","locale":"en-GB"}'::JSONB) #> '{data,content}' IS NOT NULL
  AND NOT (public.rpc_get_page('{"page_type":"airport","entity_key":"SGN","locale":"en-GB"}'::JSONB)->'data' ? 'featured_outbound_routes'),
  'airport page exposes its canonical entity without embedded legacy routes'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes('{"scope":{"type":"origin_airport","key":"SGN"},"filters":{},"page_size":100}'::JSONB)->'data') > 0
  AND NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(public.rpc_search_routes('{"scope":{"type":"origin_airport","key":"SGN"},"filters":{},"page_size":100}'::JSONB)->'data') item
    WHERE item->>'from' <> 'SGN'
  ),
  'origin-airport search returns only routes from that airport'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"route","entity_key":"ho-chi-minh-city-london","locale":"en-GB"}'::JSONB) #>> '{data,route,origin,slug}' = 'ho-chi-minh-city',
  'route page exposes its canonical origin'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes('{"scope":{"type":"city_pair","from":"ho-chi-minh-city","to":"london"},"filters":{},"page_size":100}'::JSONB)->'data') > 0,
  'route search supports one canonical city pair'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes('{"scope":{"type":"city_pair","from":"ho-chi-minh-city","to":"london"},"filters":{"max_amount":1,"currency":"USD"},"page_size":100}'::JSONB)->'data') = 0,
  'route above the maximum amount does not pass the price filter'
);

ROLLBACK;
