\set ON_ERROR_STOP on
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.test_assert(p_condition BOOLEAN,p_message TEXT) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF NOT COALESCE(p_condition,FALSE) THEN RAISE EXCEPTION 'ASSERTION FAILED: %',p_message; END IF; END; $$;

SELECT pg_temp.test_assert(jsonb_array_length(public.rpc_search_places('{"query":"lon","locale":"en-GB","limit":8}'::jsonb)#>'{data}') >= 1,'aliases/cities/airports/metros are searchable');
SELECT pg_temp.test_assert(public.rpc_get_homepage_discovery('{"origin":"SGN","max_stops":3,"limit":20}'::jsonb)#>'{meta,facets,stops}' IS NOT NULL,'homepage exposes route filters');
SELECT pg_temp.test_assert(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.rpc_get_homepage_discovery('{"origin":"SGN","max_stops":3,"max_duration_minutes":1000,"connection_airports":["SIN"],"limit":100}'::jsonb)#>'{data,route_map}') item WHERE (item->>'duration_minutes')::int>1000 OR NOT item->'connection_airports'?'SIN'),'homepage applies duration and connection filters');
SELECT pg_temp.test_assert(public.rpc_get_city_page('{"city_slug":"bangkok","locale":"en-GB"}'::jsonb)#>'{data,structured_facts}' IS NOT NULL,'city has cited structured facts');
SELECT pg_temp.test_assert(public.rpc_get_city_page('{"city_slug":"bangkok","locale":"en-GB"}'::jsonb)#>'{data,price_summary}' IS NOT NULL,'city has explicit price state');
SELECT pg_temp.test_assert(public.rpc_get_airport_page('{"airport_iata":"BKK","locale":"en-GB"}'::jsonb)#>'{data,terminals}' IS NOT NULL,'airport has terminals');
SELECT pg_temp.test_assert(public.rpc_get_airport_page('{"airport_iata":"BKK","locale":"en-GB"}'::jsonb)#>'{data,facilities}' IS NOT NULL,'airport has facilities');
SELECT pg_temp.test_assert(public.rpc_get_route_page('{"route_slug":"ho-chi-minh-city-to-london","locale":"en-GB"}'::jsonb)#>>'{data,unknowns,self_transfer}'='unknown','route page is honest about unavailable operational facts');
SELECT pg_temp.test_assert((public.rpc_search_route_options('{"route_slug":"ho-chi-minh-city-to-london","max_stops":3}'::jsonb)#>>'{meta,max_supported_stops}')::int=3,'route page supports up to three stops');
SELECT pg_temp.test_assert(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.rpc_search_route_options('{"route_slug":"ho-chi-minh-city-to-london","max_stops":3,"connection_airports":["SIN"],"max_layover_minutes":300}'::jsonb)#>'{data}') item WHERE NOT item->'connection_airports'?'SIN' OR (item->>'layover_minutes')::int>900),'route filters connection and bounded per-leg layovers');
SELECT pg_temp.test_assert(jsonb_array_length(public.rpc_search_route_options('{"route_slug":"ho-chi-minh-city-to-london","price_max":1,"currency":"USD"}'::jsonb)#>'{data}')=0,'missing price never passes a numeric price filter');
SELECT pg_temp.test_assert(public.rpc_get_route_page('{"route_slug":"ho-chi-minh-city-to-london","locale":"en-GB"}'::jsonb)#>'{data,affiliate,disclosure}' IS NOT NULL,'route reserves honest affiliate disclosure without live offers');
ROLLBACK;
