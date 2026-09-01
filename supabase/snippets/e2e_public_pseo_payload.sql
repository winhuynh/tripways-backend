-- Public pSEO responses must contain only stable public identities and opaque references.

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.assert_public_payload(p_value JSONB)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_key   TEXT;
  v_child JSONB;
BEGIN
  IF jsonb_typeof(p_value) = 'object' THEN
    FOR v_key, v_child IN SELECT key, value FROM jsonb_each(p_value)
    LOOP
      IF v_key = 'id' OR v_key LIKE '%\_id' ESCAPE '\' THEN
        RAISE EXCEPTION 'Public payload exposes forbidden key: %', v_key;
      END IF;
      PERFORM pg_temp.assert_public_payload(v_child);
    END LOOP;
  ELSIF jsonb_typeof(p_value) = 'array' THEN
    FOR v_child IN SELECT value FROM jsonb_array_elements(p_value)
    LOOP
      PERFORM pg_temp.assert_public_payload(v_child);
    END LOOP;
  ELSIF jsonb_typeof(p_value) = 'string'
    AND trim(BOTH '"' FROM p_value::TEXT) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  THEN
    RAISE EXCEPTION 'Public payload exposes a database UUID';
  END IF;
END;
$$;

DO $$
DECLARE
  v_payload         JSONB;
  v_observation_ref TEXT;
  v_handoff         JSONB;
BEGIN
  FOR v_payload IN
    SELECT payload
    FROM (
      VALUES
        (public.rpc_get_page('{"page_type":"city","entity_key":"ho-chi-minh-city","locale":"en-GB"}'::JSONB)),
        (public.rpc_get_page('{"page_type":"airport","entity_key":"SGN","locale":"en-GB"}'::JSONB)),
        (public.rpc_get_page('{"page_type":"route","entity_key":"ho-chi-minh-city-singapore","locale":"en-GB"}'::JSONB))
    ) AS responses(payload)
  LOOP
    PERFORM pg_temp.assert_public_payload(v_payload);

    IF v_payload #>> '{meta,canonical_path}' IS NULL
      OR v_payload #>> '{meta,is_indexable}' IS NULL
      OR v_payload #>> '{meta,noindex_reason}' IS NULL
      OR v_payload #>> '{meta,data_version}' !~ '^v_[0-9a-f]{32}$'
    THEN
      RAISE EXCEPTION 'Public page metadata is incomplete: %', v_payload->'meta';
    END IF;
  END LOOP;

  v_payload := public.rpc_get_page(
    '{"page_type":"route","entity_key":"ho-chi-minh-city-singapore","locale":"en-GB"}'::JSONB
  );
  v_observation_ref := v_payload #>> '{data,observations,0,observation_ref}';

  IF v_observation_ref !~ '^obs_[0-9a-f]{32}$' THEN
    RAISE EXCEPTION 'Route page does not expose an opaque observation reference';
  END IF;

  v_handoff := public.rpc_get_flight_affiliate_handoff(v_observation_ref);
  IF v_handoff #>> '{data,url}' NOT LIKE 'https://www.aviasales.com/%' THEN
    RAISE EXCEPTION 'Opaque observation reference did not resolve through the allowlisted handoff';
  END IF;

  PERFORM pg_temp.assert_public_payload(public.rpc_search_routes(
    '{"scope":{"type":"origin_airport","key":"SGN"},"filters":{},"page_size":20}'::JSONB
  ));
END;
$$;

ROLLBACK;
