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
  jsonb_array_length(public.rpc_search_places('{"query":"lon","locale":"en-GB","limit":8}'::JSONB)->'data') >= 1,
  'aliases, cities, airports and metros are searchable'
);

SELECT pg_temp.test_assert(
  (public.rpc_get_homepage_statistics() #>> '{data,published_direct_route_count}')::INTEGER > 0,
  'homepage statistics use the current published route projection'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"homepage","entity_key":"homepage","locale":"en-GB"}'::JSONB) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'homepage is not a pSEO page contract'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB) #> '{data,structured_facts}' IS NOT NULL,
  'city has cited structured facts'
);

SELECT pg_temp.test_assert(
  NOT (public.rpc_get_page('{"page_type":"city","entity_key":"bangkok","locale":"en-GB"}'::JSONB)->'data' ? 'featured_airlines'),
  'city does not expose a standalone airline section'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"airport","entity_key":"BKK","locale":"en-GB"}'::JSONB) #> '{data,arrival,steps}' IS NOT NULL
  AND public.rpc_get_page('{"page_type":"airport","entity_key":"BKK","locale":"en-GB"}'::JSONB) #> '{data,departure,steps}' IS NOT NULL
  AND public.rpc_get_page('{"page_type":"airport","entity_key":"BKK","locale":"en-GB"}'::JSONB) #> '{data,transport}' IS NOT NULL
  AND public.rpc_get_page('{"page_type":"airport","entity_key":"BKK","locale":"en-GB"}'::JSONB) #> '{data,provenance}' IS NOT NULL
  AND NOT (public.rpc_get_page('{"page_type":"airport","entity_key":"BKK","locale":"en-GB"}'::JSONB)->'data' ? 'featured_outbound_routes'),
  'airport has journey-led modules without embedded legacy routes'
);

SELECT pg_temp.test_assert(
  (public.rpc_search_routes('{"scope":{"type":"airport","key":"BKK","direction":"from"},"filters":{},"page_size":100}'::JSONB) #>> '{meta,total}')::INTEGER > 0
  AND NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(public.rpc_search_routes('{"scope":{"type":"airport","key":"BKK","direction":"from"},"filters":{},"page_size":100}'::JSONB)->'data') item
    WHERE (item->>'stops')::INTEGER <> 0 OR item->>'from' <> 'BKK'
  ),
  'airport from-search returns only verified direct services from that airport'
);

SELECT pg_temp.test_assert(
  (public.rpc_search_routes('{"scope":{"type":"airport","key":"BKK","direction":"to"},"filters":{},"page_size":100}'::JSONB) #>> '{meta,total}')::INTEGER > 0
  AND NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(public.rpc_search_routes('{"scope":{"type":"airport","key":"BKK","direction":"to"},"filters":{},"page_size":100}'::JSONB)->'data') item
    WHERE (item->>'stops')::INTEGER <> 0 OR item->>'to' <> 'BKK'
  ),
  'airport to-search returns only verified direct services to that airport'
);

SELECT pg_temp.test_assert(
  public.rpc_get_page('{"page_type":"route","entity_key":"ho-chi-minh-city-to-london","locale":"en-GB"}'::JSONB) #>> '{data,unknowns,self_transfer}' = 'unknown',
  'route page is honest about unavailable operational facts'
);

SELECT pg_temp.test_assert(
  (public.rpc_search_routes('{"scope":{"type":"city_pair","from":"ho-chi-minh-city","to":"london"},"filters":{"max_stops":3},"page_size":100}'::JSONB) #>> '{meta,total}')::INTEGER > 0,
  'route search supports direct and connecting options'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes('{"scope":{"type":"city_pair","from":"ho-chi-minh-city","to":"london"},"filters":{"max_stops":3,"price_max":1,"currency":"USD"},"page_size":100}'::JSONB)->'data') = 0,
  'missing price never passes a numeric price filter'
);

ROLLBACK;
