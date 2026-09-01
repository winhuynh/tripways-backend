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
  )->'data') = 8,
  'origin city scope returns the deterministic direct and one-stop matrix'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes(
    '{"scope":{"type":"origin_city","key":"ho-chi-minh-city"},"filters":{"currency":"USD","max_amount":100},"page_size":100}'::JSONB
  )->'data') = 3,
  'bounded price filters apply to the origin city scope'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes(
    '{"scope":{"type":"origin_city","key":"ho-chi-minh-city"},"filters":{"departure_airports":["SGN"],"destination_countries":["TH"],"destination_regions":["Asia"],"airlines":["VJ"],"route_type":"international","days_of_week":[2],"departure_time_buckets":["early_morning"],"max_duration_minutes":100},"page_size":100}'::JSONB
  )->'data') = 1,
  'city filter combination resolves to the seeded VJ fixture'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes(
    '{"scope":{"type":"city_pair","from":"ho-chi-minh-city","to":"london"},"filters":{"max_stops":1,"connection_airports":["SIN"],"max_layover_minutes":60,"cabin":"business"},"page_size":100}'::JSONB
  )->'data') = 2,
  'route filters return both seeded SIN connections'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_search_routes(
    '{"scope":{"type":"airport","key":"BKK","direction":"from"},"filters":{"max_stops":1,"counterpart_query":"tokyo","counterpart_countries":["JP"],"counterpart_regions":["Asia"],"route_type":"international","airlines":["TG"]},"page_size":100}'::JSONB
  )->'data') = 1,
  'airport counterpart filters resolve the BKK to Tokyo fixture'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(public.rpc_search_routes(
      '{"scope":{"type":"airport","key":"BKK","direction":"from"},"filters":{},"page_size":100}'::JSONB
    )->'data') AS route
    WHERE (route->>'stops')::INTEGER <> 0
  ),
  'airport discovery exposes operated nonstop services only'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM public.airport_page_read_models AS airport_page
    JOIN public.publication_versions AS version
      ON version.id = airport_page.publication_version_id
      AND version.is_current = TRUE
    WHERE (
      public.rpc_search_routes(jsonb_build_object(
        'scope', jsonb_build_object(
          'type', 'airport',
          'key', airport_page.airport_iata,
          'direction', 'from'
        ),
        'filters', '{}'::JSONB,
        'page_size', 100
      )) #>> '{meta,total}'
    )::INTEGER = 0
  ),
  'every published airport page has a default outbound route fixture'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes(
    '{"scope":{"type":"origin_city","key":"ho-chi-minh-city"},"filters":{"max_stops":1},"page_size":3,"after":null}'::JSONB
  ) #>> '{meta,next_cursor}' = 'offset:3',
  'bounded search returns a deterministic next cursor'
);

SELECT pg_temp.test_assert(
  (public.rpc_search_routes(
    '{"scope":{"type":"origin_city","key":"ho-chi-minh-city"},"filters":{"max_stops":1},"page_size":3,"after":null}'::JSONB
  ) #>> '{meta,total}')::INTEGER = 8,
  'search total is calculated before pagination'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM public.flight_route_options AS option
    INNER JOIN public.publication_versions AS version
      ON version.id = option.publication_version_id
      AND version.is_current = TRUE
    LEFT JOIN public.pseo_pages AS page
      ON page.canonical_path = option.route_path
      AND page.status = 'published'
    WHERE page.id IS NULL
  ),
  'every seeded search route resolves to a published pSEO page'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes(
    '{"scope":{"type":"global"},"filters":{"unexpected":true},"page_size":20}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'SQL boundary rejects unknown filter fields'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes(
    '{"scope":{"type":"global"},"filters":{"max_stops":2},"page_size":20}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'SQL boundary rejects stop counts outside the 0-stop and 1-stop projection'
);

SELECT pg_temp.test_assert(
  public.rpc_search_routes(
    '{"scope":{"type":"global"},"filters":{"currency":"INVALID"},"page_size":20}'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'SQL boundary rejects invalid currencies'
);

ROLLBACK;
