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
  public.rpc_get_city_overview('{"city_slug":"bangkok","locale":"en-GB"}') #>> '{data,city,slug}' = 'bangkok',
  'overview returns Bangkok'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_get_city_airports('{"city_slug":"bangkok"}') #> '{data}') = 2,
  'airports returns BKK and DMK'
);

WITH airport_payload AS (
  SELECT public.rpc_get_city_airports(
    '{"city_slug":"bangkok","locale":"en-GB"}'
  ) AS response
),
airport_items AS (
  SELECT item
  FROM airport_payload
  CROSS JOIN LATERAL jsonb_array_elements(response -> 'data') AS item
),
airport_contract AS (
  SELECT
    item ->> 'iata' AS iata,
    item ->> 'hub_label' AS hub_label,
    item ->> 'description' AS description,
    (item ->> 'display_order')::INTEGER AS display_order,
    (item ->> 'direct_destination_count')::INTEGER AS direct_destination_count,
    (item ->> 'domestic_destination_count')::INTEGER AS domestic_destination_count,
    (item ->> 'international_destination_count')::INTEGER AS international_destination_count,
    (item ->> 'domestic_destination_percentage')::INTEGER AS domestic_destination_percentage,
    (item ->> 'international_destination_percentage')::INTEGER AS international_destination_percentage,
    (item ->> 'airline_count')::INTEGER AS airline_count,
    item ->> 'dominant_airline_business_model' AS dominant_airline_business_model
  FROM airport_items
)
SELECT pg_temp.test_assert(
  (
    SELECT
      hub_label = 'MAIN HUB'
      AND description IS NOT NULL
      AND display_order = 1
      AND direct_destination_count = 3
      AND domestic_destination_count = 0
      AND international_destination_count = 3
      AND domestic_destination_percentage = 0
      AND international_destination_percentage = 100
      AND airline_count = 1
      AND dominant_airline_business_model = 'full_service'
    FROM airport_contract
    WHERE iata = 'BKK'
  ),
  'BKK returns complete editorial and derived hub statistics'
);

WITH airport_payload AS (
  SELECT public.rpc_get_city_airports(
    '{"city_slug":"bangkok","locale":"en-GB"}'
  ) AS response
),
airport_items AS (
  SELECT item
  FROM airport_payload
  CROSS JOIN LATERAL jsonb_array_elements(response -> 'data') AS item
),
airport_contract AS (
  SELECT
    item ->> 'iata' AS iata,
    item ->> 'hub_label' AS hub_label,
    item ->> 'description' AS description,
    (item ->> 'display_order')::INTEGER AS display_order,
    (item ->> 'direct_destination_count')::INTEGER AS direct_destination_count,
    (item ->> 'domestic_destination_count')::INTEGER AS domestic_destination_count,
    (item ->> 'international_destination_count')::INTEGER AS international_destination_count,
    (item ->> 'domestic_destination_percentage')::INTEGER AS domestic_destination_percentage,
    (item ->> 'international_destination_percentage')::INTEGER AS international_destination_percentage,
    (item ->> 'airline_count')::INTEGER AS airline_count,
    item ->> 'dominant_airline_business_model' AS dominant_airline_business_model
  FROM airport_items
)
SELECT pg_temp.test_assert(
  (
    SELECT
      hub_label = 'LOW-COST HUB'
      AND description IS NOT NULL
      AND display_order = 2
      AND direct_destination_count = 3
      AND domestic_destination_count = 1
      AND international_destination_count = 2
      AND domestic_destination_percentage = 33
      AND international_destination_percentage = 67
      AND airline_count = 1
      AND dominant_airline_business_model = 'low_cost'
    FROM airport_contract
    WHERE iata = 'DMK'
  ),
  'DMK returns complete editorial and derived hub statistics'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_get_city_airlines('{"city_slug":"bangkok"}') #> '{data}') >= 2,
  'airlines returns seeded direct operators'
);

WITH quick_facts AS (
  SELECT public.rpc_get_city_quick_facts(
    '{"city_slug":"bangkok","locale":"en-GB"}'
  ) AS response
)
SELECT pg_temp.test_assert(
  (
    SELECT
      (response #>> '{data,airport_count}')::INTEGER = 2
      AND (response #>> '{data,direct_destination_count}')::INTEGER = 5
      AND (response #>> '{data,direct_country_count}')::INTEGER = 5
      AND (response #>> '{data,airline_count}')::INTEGER = 2
      AND response #>> '{data,shortest_route,destination_name}' = 'Chiang Mai'
      AND response #>> '{data,shortest_route,route_path}' = '/flights/bangkok-to-chiang-mai'
      AND (response #>> '{data,shortest_route,duration_minutes}')::INTEGER = 75
      AND response #>> '{data,longest_route,destination_name}' = 'Paris'
      AND response #>> '{data,longest_route,route_path}' = '/flights/bangkok-to-paris'
      AND (response #>> '{data,longest_route,duration_minutes}')::INTEGER = 785
      AND response #>> '{meta,data_version}' IS NOT NULL
      AND response -> 'error' = 'null'::JSONB
    FROM quick_facts
  ),
  'quick facts returns one complete versioned city read model'
);

WITH route_map AS (
  SELECT public.rpc_get_city_route_map(
    jsonb_build_object(
      'city_slug', 'bangkok',
      'locale', 'en-GB',
      'limit', 100
    )
  ) AS response
)
SELECT pg_temp.test_assert(
  (
    SELECT
      response #>> '{data,origin,type}' = 'city'
      AND response #>> '{data,origin,name}' = 'Bangkok'
      AND response #>> '{data,origin,slug}' = 'bangkok'
      AND (response #>> '{data,origin,latitude}')::DOUBLE PRECISION = 13.7563
      AND (response #>> '{data,origin,longitude}')::DOUBLE PRECISION = 100.5018
      AND jsonb_array_length(response #> '{data,destinations}') = 5
      AND (response #>> '{meta,total}')::INTEGER = 5
      AND (response #>> '{meta,omitted_destination_count}')::INTEGER = 0
      AND (response #>> '{meta,limit}')::INTEGER = 100
      AND response #>> '{meta,data_version}' IS NOT NULL
      AND response -> 'error' = 'null'::JSONB
    FROM route_map
  ),
  'route map returns the versioned Bangkok origin and five destination cities'
);

WITH route_map AS (
  SELECT public.rpc_get_city_route_map(
    jsonb_build_object(
      'city_slug', 'bangkok',
      'locale', 'en-GB',
      'origin_airports', jsonb_build_array('BKK'),
      'limit', 100
    )
  ) AS response
),
destinations AS (
  SELECT destination
  FROM route_map
  CROSS JOIN LATERAL jsonb_array_elements(
    response #> '{data,destinations}'
  ) AS destination
)
SELECT pg_temp.test_assert(
  (
    SELECT
      count(*) = 3
      AND bool_and(destination #>> '{origin_airports,0}' = 'BKK')
      AND bool_and((destination ->> 'latitude') IS NOT NULL)
      AND bool_and((destination ->> 'longitude') IS NOT NULL)
      AND bool_and((destination ->> 'route_path') LIKE '/flights/bangkok-to-%')
    FROM destinations
  ),
  'route map filters by origin airport and returns complete destination geometry'
);

SELECT pg_temp.test_assert(
  (public.rpc_get_city_insights('{"city_slug":"bangkok"}') #>> '{data,direct_country_count}')::INTEGER >= 4,
  'insights returns direct country count'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_get_city_internal_links('{"city_slug":"bangkok"}') #> '{data}') >= 2,
  'internal links returns semantic groups'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(public.rpc_get_city_faqs('{"city_slug":"bangkok"}') #> '{data}') = 4,
  'FAQs returns published content'
);

SELECT pg_temp.test_assert(
  public.rpc_get_city_overview(
    '{"city_slug":"singapore","locale":"en-GB"}'
  ) #>> '{data,city,slug}' = 'singapore',
  'Singapore overview resolves through the generic city read model'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_city_airports('{"city_slug":"singapore"}') #> '{data}'
  ) = 1,
  'Singapore returns Changi as its city airport hub'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_city_page(
      '{"city_slug":"singapore","locale":"en-GB","destination_limit":24}'
    ) #> '{data,featured_destinations}'
  ) = 5,
  'Singapore returns five direct destinations'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_city_route_map(
      '{"city_slug":"singapore","locale":"en-GB","limit":100}'
    ) #> '{data,destinations}'
  ) = 5,
  'Singapore route map reuses the generic city route-map read model'
);

SELECT pg_temp.test_assert(
  (
    public.rpc_get_city_quick_facts(
      '{"city_slug":"singapore","locale":"en-GB"}'
    ) #>> '{data,direct_destination_count}'
  )::INTEGER = 5,
  'Singapore quick facts are refreshed from its direct-route graph'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_city_faqs('{"city_slug":"singapore"}') #> '{data}'
  ) = 4,
  'Singapore returns four published questions'
);

SELECT pg_temp.test_assert(
  (
    SELECT sum(jsonb_array_length(link_group -> 'links')) >= 4
    FROM jsonb_array_elements(
      public.rpc_get_city_internal_links(
        '{"city_slug":"singapore","locale":"en-GB"}'
      ) #> '{data}'
    ) AS link_group
  ),
  'Singapore returns route and source-city internal links'
);

SELECT pg_temp.test_assert(
  public.rpc_get_city_overview('{}') #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'overview rejects invalid identity'
);

SELECT pg_temp.test_assert(
  public.rpc_get_city_airports('{"city_slug":"missing"}') #>> '{error,code}' = 'ERR_CITY_NOT_FOUND',
  'section read model reports missing city'
);

SELECT pg_temp.test_assert(
  NOT has_function_privilege('anon', 'public.rpc_get_city_overview(jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'public.rpc_get_city_faqs(jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public.rpc_get_city_quick_facts(jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public.rpc_get_city_route_map(jsonb)', 'EXECUTE'),
  'public clients cannot execute city read-model RPCs'
);

ROLLBACK;
