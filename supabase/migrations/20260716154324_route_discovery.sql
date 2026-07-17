-- Source: supabase/sql_src/schema/public/flight_services.sql
-- Table: public.flight_services
-- Feature: Route Discovery
-- Purpose: Store recurring flight schedule patterns used to build route options.
-- Responsibilities: Preserve route attribution, operating days, local times, and source lineage.

CREATE TABLE public.flight_services (
  id                    UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_route_id       UUID           NOT NULL REFERENCES public.flight_routes (id),
  operating_airline_id  UUID           NOT NULL REFERENCES public.airlines (id),
  marketing_airline_id  UUID           NULL REFERENCES public.airlines (id),
  flight_number         TEXT           NOT NULL,
  valid_from            DATE           NOT NULL,
  valid_to              DATE           NOT NULL,
  days_of_week          SMALLINT[]     NOT NULL,
  departure_local_time  TIME           NOT NULL,
  arrival_local_time    TIME           NOT NULL,
  arrival_day_offset    SMALLINT       NOT NULL DEFAULT 0,
  duration_minutes      INTEGER        NOT NULL,
  aircraft_type         TEXT           NULL,
  confidence_score      NUMERIC(4, 3)  NOT NULL,
  source_id             UUID           NOT NULL REFERENCES admin.data_sources (id),
  source_record_id      TEXT           NOT NULL,
  last_verified_at      TIMESTAMPTZ    NOT NULL,
  created_at            TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT flight_services_source_record_key
    UNIQUE (source_id, source_record_id),

  CONSTRAINT flight_services_flight_number_check
    CHECK (
      flight_number = btrim(flight_number)
      AND flight_number ~ '^[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?$'
    ),

  CONSTRAINT flight_services_validity_check
    CHECK (valid_from <= valid_to),

  CONSTRAINT flight_services_days_check
    CHECK (
      cardinality(days_of_week) BETWEEN 1 AND 7
      AND days_of_week <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::SMALLINT[]
    ),

  CONSTRAINT flight_services_arrival_offset_check
    CHECK (arrival_day_offset BETWEEN 0 AND 2),

  CONSTRAINT flight_services_duration_check
    CHECK (duration_minutes BETWEEN 1 AND 1440),

  CONSTRAINT flight_services_aircraft_type_check
    CHECK (
      aircraft_type IS NULL
      OR (
        aircraft_type = btrim(aircraft_type)
        AND char_length(aircraft_type) BETWEEN 1 AND 32
      )
    ),

  CONSTRAINT flight_services_confidence_check
    CHECK (confidence_score BETWEEN 0 AND 1)
);

CREATE INDEX flight_services_route_validity_idx
ON public.flight_services USING btree (flight_route_id, valid_from, valid_to);

CREATE INDEX flight_services_operating_airline_idx
ON public.flight_services USING btree (operating_airline_id);

CREATE INDEX flight_services_marketing_airline_idx
ON public.flight_services USING btree (marketing_airline_id)
WHERE marketing_airline_id IS NOT NULL;

ALTER TABLE public.flight_services ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.flight_services FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flight_services TO service_role;

-- Source: supabase/sql_src/schema/public/route_options.sql
-- Table: public.route_options
-- Feature: Route Discovery
-- Purpose: Store precomputed direct and one-stop schedule options for bounded search.
-- Responsibilities: Preserve filterable route shape, duration, schedule validity, and data version.

CREATE TABLE public.route_options (
  id                      UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_airport_id       UUID           NOT NULL REFERENCES public.airports (id),
  destination_airport_id  UUID           NOT NULL REFERENCES public.airports (id),
  stop_count              SMALLINT       NOT NULL,
  service_ids             UUID[]         NOT NULL,
  connection_airport_ids  UUID[]         NOT NULL DEFAULT '{}'::UUID[],
  operating_airline_ids   UUID[]         NOT NULL,
  marketing_airline_ids   UUID[]         NOT NULL,
  total_flight_minutes    INTEGER        NOT NULL,
  layover_minutes         INTEGER        NOT NULL DEFAULT 0,
  total_duration_minutes  INTEGER        NOT NULL,
  departure_local_time    TIME           NOT NULL,
  arrival_local_time      TIME           NOT NULL,
  arrival_day_offset      SMALLINT       NOT NULL,
  valid_from              DATE           NOT NULL,
  valid_to                DATE           NOT NULL,
  days_of_week            SMALLINT[]     NOT NULL,
  confidence_score        NUMERIC(4, 3)  NOT NULL,
  data_version            UUID           NOT NULL,
  generated_at            TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT route_options_services_key
    UNIQUE (service_ids),

  CONSTRAINT route_options_direction_check
    CHECK (origin_airport_id <> destination_airport_id),

  CONSTRAINT route_options_stop_count_check
    CHECK (stop_count IN (0, 1)),

  CONSTRAINT route_options_shape_check
    CHECK (
      cardinality(service_ids) = stop_count + 1
      AND cardinality(connection_airport_ids) = stop_count
      AND cardinality(operating_airline_ids) = stop_count + 1
      AND cardinality(marketing_airline_ids) = stop_count + 1
    ),

  CONSTRAINT route_options_duration_check
    CHECK (
      total_flight_minutes > 0
      AND layover_minutes >= 0
      AND total_duration_minutes = total_flight_minutes + layover_minutes
    ),

  CONSTRAINT route_options_arrival_offset_check
    CHECK (arrival_day_offset BETWEEN 0 AND 3),

  CONSTRAINT route_options_validity_check
    CHECK (valid_from <= valid_to),

  CONSTRAINT route_options_days_check
    CHECK (
      cardinality(days_of_week) BETWEEN 1 AND 7
      AND days_of_week <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::SMALLINT[]
    ),

  CONSTRAINT route_options_confidence_check
    CHECK (confidence_score BETWEEN 0 AND 1)
);

CREATE INDEX route_options_search_idx
ON public.route_options USING btree (
  origin_airport_id,
  destination_airport_id,
  stop_count,
  total_duration_minutes
);

CREATE INDEX route_options_operating_airlines_idx
ON public.route_options USING gin (operating_airline_ids);

CREATE INDEX route_options_connections_idx
ON public.route_options USING gin (connection_airport_ids);

ALTER TABLE public.route_options ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.route_options FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_options TO service_role;

-- Source: supabase/sql_src/functions/route_discovery/calculate_layover_minutes.sql
-- ============================================================================
-- Function: public.calculate_layover_minutes
-- Feature: Route Discovery
-- Purpose: Calculate connection time using two local timestamps at the same airport.
-- Responsibilities: Normalize a same-day or next-day departure into a positive minute interval.
-- Notes: The caller applies the accepted minimum and maximum connection bounds.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_layover_minutes(
  p_arrival_local_time TIME,
  p_arrival_day_offset SMALLINT,
  p_next_departure_local_time TIME
)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
  WITH minute_values AS (
    SELECT
      (
        p_arrival_day_offset::INTEGER * 1440
        + extract(HOUR FROM p_arrival_local_time)::INTEGER * 60
        + extract(MINUTE FROM p_arrival_local_time)::INTEGER
      ) AS arrival_minute,
      (
        extract(HOUR FROM p_next_departure_local_time)::INTEGER * 60
        + extract(MINUTE FROM p_next_departure_local_time)::INTEGER
      ) AS departure_minute
  )
  SELECT
    CASE
      WHEN mod(mod(departure_minute - arrival_minute, 1440) + 1440, 1440) = 0
        THEN 1440
      ELSE mod(mod(departure_minute - arrival_minute, 1440) + 1440, 1440)
    END
  FROM minute_values;
$$;

REVOKE ALL ON FUNCTION public.calculate_layover_minutes(TIME, SMALLINT, TIME) FROM public;
GRANT EXECUTE ON FUNCTION public.calculate_layover_minutes(TIME, SMALLINT, TIME) TO service_role;

-- Source: supabase/sql_src/functions/route_discovery/refresh_route_options.sql
-- ============================================================================
-- Function: public.refresh_route_options
-- Feature: Route Discovery
-- Purpose: Rebuild direct and one-stop Route Discovery options atomically.
-- Responsibilities: Enforce route status, schedule overlap, connection bounds, and versioning.
-- Notes: This privileged maintenance operation is executable only by service_role.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.refresh_route_options()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Refresh state
  ------------------------------------------------------------------
  v_data_version UUID := gen_random_uuid();
  v_direct_count INTEGER := 0;
  v_one_stop_count INTEGER := 0;
BEGIN
  -- STEP 01: Serialize refreshes and replace the prior read model in this transaction.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('public.refresh_route_options', 0)
  );
  DELETE FROM public.route_options;

  -- STEP 02: Materialize schedule options backed by an eligible direct route.
  INSERT INTO public.route_options (
    origin_airport_id,
    destination_airport_id,
    stop_count,
    service_ids,
    connection_airport_ids,
    operating_airline_ids,
    marketing_airline_ids,
    total_flight_minutes,
    layover_minutes,
    total_duration_minutes,
    departure_local_time,
    arrival_local_time,
    arrival_day_offset,
    valid_from,
    valid_to,
    days_of_week,
    confidence_score,
    data_version
  )
  SELECT
    route.origin_airport_id,
    route.destination_airport_id,
    0,
    ARRAY[service.id],
    '{}'::UUID[],
    ARRAY[service.operating_airline_id],
    ARRAY[COALESCE(service.marketing_airline_id, service.operating_airline_id)],
    service.duration_minutes,
    0,
    service.duration_minutes,
    service.departure_local_time,
    service.arrival_local_time,
    service.arrival_day_offset,
    service.valid_from,
    service.valid_to,
    service.days_of_week,
    LEAST(route.confidence_score, service.confidence_score),
    v_data_version
  FROM public.flight_services service
  JOIN public.flight_routes route ON route.id = service.flight_route_id
  WHERE route.status IN ('verified_active', 'likely_active', 'seasonal');

  GET DIAGNOSTICS v_direct_count = ROW_COUNT;

  -- STEP 03: Materialize one-stop pairs with overlapping validity and safe connection time.
  INSERT INTO public.route_options (
    origin_airport_id,
    destination_airport_id,
    stop_count,
    service_ids,
    connection_airport_ids,
    operating_airline_ids,
    marketing_airline_ids,
    total_flight_minutes,
    layover_minutes,
    total_duration_minutes,
    departure_local_time,
    arrival_local_time,
    arrival_day_offset,
    valid_from,
    valid_to,
    days_of_week,
    confidence_score,
    data_version
  )
  SELECT
    first_route.origin_airport_id,
    second_route.destination_airport_id,
    1,
    ARRAY[first_service.id, second_service.id],
    ARRAY[first_route.destination_airport_id],
    ARRAY[first_service.operating_airline_id, second_service.operating_airline_id],
    ARRAY[
      COALESCE(first_service.marketing_airline_id, first_service.operating_airline_id),
      COALESCE(second_service.marketing_airline_id, second_service.operating_airline_id)
    ],
    first_service.duration_minutes + second_service.duration_minutes,
    connection.layover_minutes,
    first_service.duration_minutes
      + connection.layover_minutes
      + second_service.duration_minutes,
    first_service.departure_local_time,
    second_service.arrival_local_time,
    first_service.arrival_day_offset
      + CASE
        WHEN second_service.departure_local_time <= first_service.arrival_local_time THEN 1
        ELSE 0
      END
      + second_service.arrival_day_offset,
    GREATEST(first_service.valid_from, second_service.valid_from),
    LEAST(first_service.valid_to, second_service.valid_to),
    schedule_days.days_of_week,
    LEAST(
      first_route.confidence_score,
      second_route.confidence_score,
      first_service.confidence_score,
      second_service.confidence_score
    ),
    v_data_version
  FROM public.flight_services first_service
  JOIN public.flight_routes first_route ON first_route.id = first_service.flight_route_id
  JOIN public.flight_routes second_route
    ON second_route.origin_airport_id = first_route.destination_airport_id
    AND second_route.destination_airport_id <> first_route.origin_airport_id
  JOIN public.flight_services second_service
    ON second_service.flight_route_id = second_route.id
  CROSS JOIN LATERAL (
    SELECT public.calculate_layover_minutes(
      first_service.arrival_local_time,
      first_service.arrival_day_offset,
      second_service.departure_local_time
    ) AS layover_minutes
  ) connection
  CROSS JOIN LATERAL (
    SELECT ARRAY(
      SELECT day_value
      FROM UNNEST(first_service.days_of_week) day_value
      INTERSECT
      SELECT day_value
      FROM UNNEST(second_service.days_of_week) day_value
      ORDER BY day_value
    )::SMALLINT[] AS days_of_week
  ) schedule_days
  WHERE first_route.status IN ('verified_active', 'likely_active', 'seasonal')
    AND second_route.status IN ('verified_active', 'likely_active', 'seasonal')
    AND GREATEST(first_service.valid_from, second_service.valid_from)
      <= LEAST(first_service.valid_to, second_service.valid_to)
    AND cardinality(schedule_days.days_of_week) > 0
    AND connection.layover_minutes BETWEEN 45 AND 1440;

  GET DIAGNOSTICS v_one_stop_count = ROW_COUNT;

  -- STEP 04: Return refresh metadata for operational logging and verification.
  RETURN jsonb_build_object(
    'data_version', v_data_version,
    'direct_count', v_direct_count,
    'one_stop_count', v_one_stop_count,
    'total_count', v_direct_count + v_one_stop_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_route_options() FROM public;
GRANT EXECUTE ON FUNCTION public.refresh_route_options() TO service_role;

-- Source: supabase/sql_src/functions/route_discovery/rpc_search_routes.sql
-- ============================================================================
-- Function: public.rpc_search_routes
-- Feature: Route Discovery
-- Purpose: Search the precomputed route graph through a stable JSON contract.
-- Responsibilities: Validate filters, resolve codes, rank options, paginate, and return facets.
-- Notes: The service-role-only transport keeps direct table access closed to public clients.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_search_routes(p_input JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  ------------------------------------------------------------------
  -- Route identity
  ------------------------------------------------------------------
  v_from TEXT;
  v_to TEXT;
  v_origin_id UUID;
  v_destination_id UUID;

  ------------------------------------------------------------------
  -- Filters and pagination
  ------------------------------------------------------------------
  v_max_stops INTEGER := 1;
  v_max_duration_minutes INTEGER;
  v_max_layover_minutes INTEGER;
  v_departure_window TEXT;
  v_limit INTEGER := 20;
  v_offset INTEGER := 0;
  v_airline_codes TEXT[] := '{}'::TEXT[];
  v_excluded_airport_ids UUID[] := '{}'::UUID[];

  ------------------------------------------------------------------
  -- Result
  ------------------------------------------------------------------
  v_result JSONB;
BEGIN
  -- STEP 01: Validate and normalize the bounded public input contract.
  IF p_input IS NULL OR jsonb_typeof(p_input) <> 'object' THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'Request must be a JSON object.'
      )
    );
  END IF;

  v_from := upper(btrim(COALESCE(p_input->>'from', '')));
  v_to := upper(btrim(COALESCE(p_input->>'to', '')));

  IF v_from !~ '^[A-Z]{3}$' OR v_to !~ '^[A-Z]{3}$' OR v_from = v_to THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'Origin and destination must be different three-letter IATA codes.'
      )
    );
  END IF;

  IF p_input ? 'max_stops' THEN
    IF jsonb_typeof(p_input->'max_stops') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_stops must be an integer.'
        )
      );
    END IF;
    v_max_stops := (p_input->>'max_stops')::INTEGER;
  END IF;

  IF p_input ? 'limit' THEN
    IF jsonb_typeof(p_input->'limit') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'limit must be an integer.'
        )
      );
    END IF;
    v_limit := (p_input->>'limit')::INTEGER;
  END IF;

  IF p_input ? 'offset' THEN
    IF jsonb_typeof(p_input->'offset') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'offset must be an integer.'
        )
      );
    END IF;
    v_offset := (p_input->>'offset')::INTEGER;
  END IF;

  IF v_max_stops NOT BETWEEN 0 AND 1
    OR v_limit NOT BETWEEN 1 AND 100
    OR v_offset NOT BETWEEN 0 AND 10000
  THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'Pagination or stop limits are outside accepted bounds.'
      )
    );
  END IF;

  IF p_input ? 'max_duration_minutes' THEN
    IF jsonb_typeof(p_input->'max_duration_minutes') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_duration_minutes must be an integer.'
        )
      );
    END IF;
    v_max_duration_minutes := (p_input->>'max_duration_minutes')::INTEGER;
    IF v_max_duration_minutes NOT BETWEEN 1 AND 4320 THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_duration_minutes is outside accepted bounds.'
        )
      );
    END IF;
  END IF;

  IF p_input ? 'max_layover_minutes' THEN
    IF jsonb_typeof(p_input->'max_layover_minutes') <> 'number' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_layover_minutes must be an integer.'
        )
      );
    END IF;
    v_max_layover_minutes := (p_input->>'max_layover_minutes')::INTEGER;
    IF v_max_layover_minutes NOT BETWEEN 45 AND 1440 THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'max_layover_minutes is outside accepted bounds.'
        )
      );
    END IF;
  END IF;

  v_departure_window := nullif(lower(btrim(COALESCE(p_input->>'departure_window', ''))), '');
  IF v_departure_window IS NOT NULL
    AND v_departure_window NOT IN ('morning', 'afternoon', 'evening', 'night') THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_INVALID_REQUEST',
        'message', 'departure_window is not supported.'
      )
    );
  END IF;

  IF p_input ? 'airlines' THEN
    IF jsonb_typeof(p_input->'airlines') <> 'array' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'airlines must be an array.'
        )
      );
    END IF;
    SELECT COALESCE(array_agg(DISTINCT upper(btrim(code))), '{}'::TEXT[])
    INTO v_airline_codes
    FROM jsonb_array_elements_text(p_input->'airlines') code;
    IF EXISTS (SELECT 1 FROM UNNEST(v_airline_codes) code WHERE code !~ '^[A-Z0-9]{2}$') THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'airlines contains an invalid IATA code.'
        )
      );
    END IF;
  END IF;

  IF p_input ? 'exclude_airports' THEN
    IF jsonb_typeof(p_input->'exclude_airports') <> 'array' THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'exclude_airports must be an array.'
        )
      );
    END IF;
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(p_input->'exclude_airports') code
      WHERE upper(btrim(code)) !~ '^[A-Z]{3}$'
    ) THEN
      RETURN jsonb_build_object(
        'data', '[]'::JSONB,
        'meta', '{}'::JSONB,
        'error', jsonb_build_object(
          'code', 'ERR_INVALID_REQUEST',
          'message', 'exclude_airports contains an invalid IATA code.'
        )
      );
    END IF;
    SELECT COALESCE(array_agg(airport.id), '{}'::UUID[])
    INTO v_excluded_airport_ids
    FROM public.airports airport
    WHERE airport.iata IN (
      SELECT upper(btrim(code))
      FROM jsonb_array_elements_text(p_input->'exclude_airports') code
    );
  END IF;

  -- STEP 02: Resolve endpoint codes without exposing internal identifiers.
  SELECT airport.id INTO v_origin_id FROM public.airports airport WHERE airport.iata = v_from;
  SELECT airport.id INTO v_destination_id FROM public.airports airport WHERE airport.iata = v_to;

  IF v_origin_id IS NULL OR v_destination_id IS NULL THEN
    RETURN jsonb_build_object(
      'data', '[]'::JSONB,
      'meta', '{}'::JSONB,
      'error', jsonb_build_object(
        'code', 'ERR_AIRPORT_NOT_FOUND',
        'message', 'Origin or destination airport was not found.'
      )
    );
  END IF;

  -- STEP 03: Apply all route filters once, then derive results and facets from the same set.
  WITH filtered AS MATERIALIZED (
    SELECT route_option.*
    FROM public.route_options route_option
    WHERE route_option.origin_airport_id = v_origin_id
      AND route_option.destination_airport_id = v_destination_id
      AND route_option.stop_count <= v_max_stops
      AND (
        v_max_duration_minutes IS NULL
        OR route_option.total_duration_minutes <= v_max_duration_minutes
      )
      AND (v_max_layover_minutes IS NULL OR route_option.layover_minutes <= v_max_layover_minutes)
      AND NOT (route_option.connection_airport_ids && v_excluded_airport_ids)
      AND (
        cardinality(v_airline_codes) = 0
        OR EXISTS (
          SELECT 1
          FROM public.airlines airline
          WHERE airline.id = ANY(route_option.operating_airline_ids)
            AND airline.iata = ANY(v_airline_codes)
        )
      )
      AND (
        v_departure_window IS NULL
        OR (
          v_departure_window = 'morning'
          AND route_option.departure_local_time >= TIME '05:00'
          AND route_option.departure_local_time < TIME '12:00'
        )
        OR (
          v_departure_window = 'afternoon'
          AND route_option.departure_local_time >= TIME '12:00'
          AND route_option.departure_local_time < TIME '17:00'
        )
        OR (
          v_departure_window = 'evening'
          AND route_option.departure_local_time >= TIME '17:00'
          AND route_option.departure_local_time < TIME '21:00'
        )
        OR (
          v_departure_window = 'night'
          AND (
            route_option.departure_local_time >= TIME '21:00'
            OR route_option.departure_local_time < TIME '05:00'
          )
        )
      )
  ),
  page AS (
    SELECT *
    FROM filtered
    ORDER BY stop_count, total_duration_minutes, confidence_score DESC, id
    LIMIT v_limit
    OFFSET v_offset
  )
  SELECT jsonb_build_object(
    'data', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', page.id,
          'from', v_from,
          'to', v_to,
          'stops', page.stop_count,
          'connection_airports', COALESCE((
            SELECT jsonb_agg(airport.iata ORDER BY position.ordinality)
            FROM UNNEST(page.connection_airport_ids)
            WITH ORDINALITY position(airport_id, ordinality)
            JOIN public.airports airport ON airport.id = position.airport_id
          ), '[]'::JSONB),
          'operating_airlines', COALESCE((
            SELECT jsonb_agg(airline.iata ORDER BY position.ordinality)
            FROM UNNEST(page.operating_airline_ids) WITH ordinality position(airline_id, ordinality)
            JOIN public.airlines airline ON airline.id = position.airline_id
          ), '[]'::JSONB),
          'total_flight_minutes', page.total_flight_minutes,
          'layover_minutes', page.layover_minutes,
          'total_duration_minutes', page.total_duration_minutes,
          'departure_local_time', to_char(page.departure_local_time, 'HH24:MI'),
          'arrival_local_time', to_char(page.arrival_local_time, 'HH24:MI'),
          'arrival_day_offset', page.arrival_day_offset,
          'valid_from', page.valid_from,
          'valid_to', page.valid_to,
          'days_of_week', page.days_of_week,
          'confidence_score', page.confidence_score,
          'data_version', page.data_version
        )
        ORDER BY page.stop_count, page.total_duration_minutes, page.confidence_score DESC, page.id
      )
      FROM page
    ), '[]'::JSONB),
    'meta', jsonb_build_object(
      'total', (SELECT count(*) FROM filtered),
      'limit', v_limit,
      'offset', v_offset,
      'facets', jsonb_build_object(
        'stops', COALESCE((
          SELECT jsonb_agg(
            jsonb_build_object('value', stop_count, 'count', option_count)
            ORDER BY stop_count
          )
          FROM (
            SELECT filtered.stop_count, count(*) AS option_count
            FROM filtered
            GROUP BY filtered.stop_count
          ) stop_facet
        ), '[]'::JSONB),
        'airlines', COALESCE((
          SELECT jsonb_agg(jsonb_build_object('value', iata, 'count', option_count) ORDER BY iata)
          FROM (
            SELECT airline.iata, count(DISTINCT filtered.id) AS option_count
            FROM filtered
            CROSS JOIN LATERAL UNNEST(filtered.operating_airline_ids) airline_id
            JOIN public.airlines airline ON airline.id = airline_id
            GROUP BY airline.iata
          ) airline_facet
        ), '[]'::JSONB)
      )
    ),
    'error', NULL
  )
  INTO v_result;

  -- STEP 04: Return one deterministic envelope for transport-level normalization.
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_search_routes(JSONB) FROM public;
GRANT EXECUTE ON FUNCTION public.rpc_search_routes(JSONB) TO service_role;

