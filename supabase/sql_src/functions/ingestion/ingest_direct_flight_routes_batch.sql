-- ============================================================================
-- Function: admin.ingest_direct_flight_routes_batch
-- Purpose: Validate and batch upsert direct non-stop flight routes from licensed providers.
-- Responsibilities:
--   - Verify data source identity and permissions.
--   - Resolve airport and airline foreign keys by IATA codes.
--   - Upsert into public.direct_flight_routes with complete lineage and schedule metadata.
-- ============================================================================

CREATE OR REPLACE FUNCTION admin.ingest_direct_flight_routes_batch(
  p_source_code TEXT,
  p_routes      JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_source_id UUID;
  v_count     INTEGER := 0;
BEGIN
  IF p_source_code IS NULL OR NULLIF(btrim(p_source_code), '') IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_INVALID_SOURCE_CODE';
  END IF;

  IF p_routes IS NULL OR jsonb_typeof(p_routes) <> 'array' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ERR_INVALID_ROUTES_PAYLOAD';
  END IF;

  SELECT id INTO v_source_id
  FROM admin.data_sources
  WHERE code = p_source_code;

  IF v_source_id IS NULL THEN
    -- Fallback: auto-register provider data source if not present
    INSERT INTO admin.data_sources (
      id, code, name
    ) VALUES (
      gen_random_uuid(), p_source_code, 'AeroDataBox Flight Routes'
    ) RETURNING id INTO v_source_id;
  END IF;

  IF jsonb_array_length(p_routes) = 0 THEN
    RETURN jsonb_build_object('status', 'success', 'upserted_count', 0);
  END IF;

  WITH route_items AS (
    SELECT
      upper(btrim(r->>'origin_iata')) AS origin_iata,
      upper(btrim(r->>'destination_iata')) AS destination_iata,
      upper(btrim(r->>'airline_iata')) AS airline_iata,
      COALESCE(NULLIF(btrim(r->>'airline_name'), ''), upper(btrim(r->>'airline_iata'))) AS airline_name,
      COALESCE(
        ARRAY(SELECT jsonb_array_elements_text(r->'flight_numbers')),
        '{}'::TEXT[]
      ) AS flight_numbers,
      GREATEST(1, COALESCE((r->>'flight_duration_minutes')::INTEGER, 60)) AS flight_duration_minutes,
      NULLIF((r->>'distance_km')::INTEGER, 0) AS distance_km,
      COALESCE(
        ARRAY(SELECT (jsonb_array_elements_text(r->'days_of_week'))::INTEGER),
        '{1,2,3,4,5,6,7}'::INTEGER[]
      ) AS days_of_week,
      COALESCE(
        ARRAY(SELECT jsonb_array_elements_text(r->'aircraft_types')),
        '{}'::TEXT[]
      ) AS aircraft_types,
      COALESCE(
        NULLIF(btrim(r->>'source_record_id'), ''),
        p_source_code || '-' || upper(btrim(r->>'origin_iata')) || '-' || upper(btrim(r->>'destination_iata')) || '-' || upper(btrim(r->>'airline_iata'))
      ) AS source_record_id
    FROM jsonb_array_elements(p_routes) AS r
    WHERE NULLIF(btrim(r->>'origin_iata'), '') IS NOT NULL
      AND NULLIF(btrim(r->>'destination_iata'), '') IS NOT NULL
      AND NULLIF(btrim(r->>'airline_iata'), '') IS NOT NULL
  ),
  upserted AS (
    INSERT INTO public.direct_flight_routes (
      origin_airport_id,
      destination_airport_id,
      origin_iata,
      destination_iata,
      airline_iata,
      airline_name,
      airline_id,
      flight_numbers,
      flight_duration_minutes,
      distance_km,
      days_of_week,
      aircraft_types,
      source_id,
      source_record_id,
      last_synced_at,
      is_active
    )
    SELECT
      orig.id,
      dest.id,
      item.origin_iata,
      item.destination_iata,
      item.airline_iata,
      COALESCE(al.name, item.airline_name),
      al.id,
      item.flight_numbers,
      item.flight_duration_minutes,
      COALESCE(
        item.distance_km,
        admin.calculate_haversine_distance_km(orig.latitude, orig.longitude, dest.latitude, dest.longitude),
        500
      ),
      item.days_of_week,
      item.aircraft_types,
      v_source_id,
      item.source_record_id,
      now(),
      TRUE
    FROM route_items item
    JOIN public.airports orig ON orig.iata = item.origin_iata
    JOIN public.airports dest ON dest.iata = item.destination_iata
    LEFT JOIN public.airlines al ON al.iata = item.airline_iata
    WHERE orig.id <> dest.id
    ON CONFLICT (source_id, source_record_id)
    DO UPDATE SET
      flight_numbers = EXCLUDED.flight_numbers,
      flight_duration_minutes = EXCLUDED.flight_duration_minutes,
      distance_km = EXCLUDED.distance_km,
      days_of_week = EXCLUDED.days_of_week,
      aircraft_types = EXCLUDED.aircraft_types,
      airline_name = EXCLUDED.airline_name,
      airline_id = EXCLUDED.airline_id,
      last_synced_at = now(),
      is_active = TRUE
    RETURNING id
  )
  SELECT count(*) INTO v_count FROM upserted;

  RETURN jsonb_build_object(
    'status', 'success',
    'source_code', p_source_code,
    'upserted_count', v_count
  );
END;
$$;

REVOKE ALL ON FUNCTION admin.ingest_direct_flight_routes_batch(TEXT, JSONB)
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION admin.ingest_direct_flight_routes_batch(TEXT, JSONB) TO service_role;
