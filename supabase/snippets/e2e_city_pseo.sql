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

INSERT INTO public.pseo_pages (
  id,
  page_type,
  entity_key,
  locale,
  canonical_path,
  display_title,
  status,
  is_indexable,
  noindex_reason
)
VALUES (
  '81000000-0000-4000-8000-000000000099',
  'city',
  'bangkok:inbound',
  'en-GB',
  '/flights-to/bangkok',
  'Direct flights to Bangkok',
  'review',
  FALSE,
  'development_fixture'
);

INSERT INTO public.city_pages (
  id,
  pseo_page_id,
  city_id,
  locale,
  route_direction,
  canonical_slug,
  h1,
  subheadline,
  seo_title,
  meta_description,
  og_title,
  og_description,
  intro,
  status,
  is_indexable,
  noindex_reason,
  content_reviewed_at
)
VALUES (
  '82000000-0000-4000-8000-000000000099',
  '81000000-0000-4000-8000-000000000099',
  '30000000-0000-4000-8000-000000000003',
  'en-GB',
  'inbound',
  'bangkok',
  'Direct flights to Bangkok',
  'Explore direct routes arriving in Bangkok.',
  'Direct Flights to Bangkok | Tripways',
  'Explore cities and airlines with direct flights to Bangkok.',
  'Direct flights to Bangkok',
  'Explore direct origins and airlines serving Bangkok.',
  'Compare direct routes arriving at Bangkok airports.',
  'review',
  FALSE,
  'development_fixture',
  '2026-07-27T00:00:00Z'
);

UPDATE public.city_pages
SET noindex_reason = 'stale_preview_state'
WHERE canonical_slug = 'bangkok'
  AND locale = 'en-GB';

SELECT public.refresh_city_pseo_read_models();

SELECT pg_temp.test_assert(
  (
    SELECT city_page.direct_counterpart_city_count
    FROM public.city_pages city_page
    WHERE city_page.city_id = '30000000-0000-4000-8000-000000000003'
      AND city_page.locale = 'en-GB'
      AND city_page.route_direction = 'inbound'
  ) >= 1,
  'inbound city pages derive direct origin-city facts'
);

SELECT pg_temp.test_assert(
  private.resolve_city_page_context('bangkok', 'en-GB', 'inbound')
    #>> '{data,city_page_id}' = '82000000-0000-4000-8000-000000000099',
  'city page context resolves the requested route direction'
);

SELECT pg_temp.test_assert(
  public.rpc_get_city_page(
    '{
      "city_slug": "bangkok",
      "locale": "en-GB",
      "destination_limit": 8
    }'::JSONB
  ) #>> '{meta,noindex_reason}' = 'development_fixture',
  'refresh derives development fixture noindex state from source rights'
);

SELECT pg_temp.test_assert(
  public.rpc_get_city_page(
    '{
      "city_slug": "bangkok",
      "locale": "en-GB",
      "destination_limit": 8
    }'::JSONB
  ) #>> '{data,city,slug}' = 'bangkok',
  'city page resolves Bangkok by canonical slug'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_city_page(
      '{
        "city_slug": "bangkok",
        "locale": "en-GB",
        "destination_limit": 8
      }'::JSONB
    ) #> '{data,airports}'
  ) = 2,
  'city page aggregates BKK and DMK'
);

SELECT pg_temp.test_assert(
  (
    public.rpc_get_city_page(
      '{
        "city_slug": "bangkok",
        "locale": "en-GB",
        "destination_limit": 8
      }'::JSONB
    ) #>> '{data,quick_facts,direct_destinations}'
  )::INTEGER >= 3,
  'city page returns multiple direct destinations'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_city_page(
      '{
        "city_slug": "bangkok",
        "locale": "en-GB",
        "destination_limit": 8
      }'::JSONB
    ) #> '{data,faqs}'
  ) >= 3,
  'city page returns seeded FAQ content'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_get_city_page(
      '{
        "city_slug": "bangkok",
        "locale": "en-GB",
        "destination_limit": 8
      }'::JSONB
    ) #> '{data,internal_link_groups}'
  ) >= 2,
  'city page returns semantic internal-link groups'
);

SELECT pg_temp.test_assert(
  public.rpc_get_city_page(
    '{
      "city_slug": "bangkok",
      "locale": "en-GB",
      "destination_limit": 8
    }'::JSONB
  ) #>> '{meta,canonical_path}' = '/flights-from/bangkok',
  'city page returns canonical path metadata'
);

SELECT pg_temp.test_assert(
  public.rpc_get_city_page(
    '{
      "city_slug": "bangkok",
      "locale": "en-GB",
      "destination_limit": 8
    }'::JSONB
  ) #>> '{meta,is_indexable}' = 'false',
  'development fixture remains non-indexable'
);

SELECT pg_temp.test_assert(
  public.rpc_get_city_page(
    '{
      "city_slug": "bangkok",
      "locale": "en-GB",
      "destination_limit": 8
    }'::JSONB
  ) #> '{meta,data_version}' IS NOT NULL,
  'city page returns a data version'
);

SELECT pg_temp.test_assert(
  (
    public.rpc_search_city_direct_routes(
      '{
        "city_slug": "bangkok",
        "origin_airports": ["DMK"],
        "limit": 20,
        "offset": 0
      }'::JSONB
    ) #>> '{meta,total}'
  )::INTEGER >= 1,
  'airport filter returns DMK routes'
);

SELECT pg_temp.test_assert(
  NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(
      public.rpc_search_city_direct_routes(
        '{
          "city_slug": "bangkok",
          "origin_airports": ["DMK"],
          "limit": 20,
          "offset": 0
        }'::JSONB
      ) #> '{data}'
    ) destination
    WHERE NOT destination->'origin_airports' ? 'DMK'
  ),
  'filtered destination cards contain only the requested origin airport'
);

SELECT pg_temp.test_assert(
  jsonb_array_length(
    public.rpc_search_city_direct_routes(
      '{
        "city_slug": "bangkok",
        "limit": 20,
        "offset": 0
      }'::JSONB
    ) #> '{meta,facets,airports}'
  ) = 2,
  'search returns both Bangkok airport facets'
);

SELECT pg_temp.test_assert(
  public.rpc_search_city_direct_routes(
    '{
      "city_slug": "bangkok",
      "origin_airports": ["INVALID"],
      "limit": 20,
      "offset": 0
    }'::JSONB
  ) #>> '{error,code}' = 'ERR_INVALID_REQUEST',
  'search rejects invalid airport codes'
);

SELECT pg_temp.test_assert(
  NOT has_function_privilege(
    'anon',
    'public.refresh_city_pseo_read_models()',
    'EXECUTE'
  ),
  'anon cannot refresh city pSEO read models'
);

SELECT pg_temp.test_assert(
  NOT has_function_privilege(
    'authenticated',
    'public.rpc_get_city_page(jsonb)',
    'EXECUTE'
  ),
  'authenticated clients cannot execute the city page RPC'
);

SELECT pg_temp.test_assert(
  NOT has_function_privilege(
    'anon',
    'public.rpc_search_city_direct_routes(jsonb)',
    'EXECUTE'
  ),
  'anon clients cannot execute the city route search RPC'
);

ROLLBACK;
