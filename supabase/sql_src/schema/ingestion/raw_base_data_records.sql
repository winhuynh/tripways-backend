-- Table: admin.raw_base_data_records
-- Feature: Base Data Ingestion
-- Purpose: Preserve bounded provider records inside the internal ingestion boundary.
-- Responsibilities: Link records to a batch and record their validation outcome.

CREATE TABLE admin.raw_base_data_records (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id          UUID         NOT NULL REFERENCES admin.raw_import_batches (id) ON DELETE CASCADE,
  record_type       TEXT         NOT NULL,
  source_key        TEXT         NOT NULL,
  payload           JSONB        NOT NULL,
  validation_state  TEXT         NOT NULL DEFAULT 'pending',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT raw_base_data_records_batch_identity_key
    UNIQUE (batch_id, record_type, source_key),

  CONSTRAINT raw_base_data_records_type_check
    CHECK (
      record_type IN (
        'country',
        'city',
        'place_alias',
        'metro_area',
        'airport',
        'airport_terminal',
        'airline',
        'flight_route',
        'flight_service',
        'route_price_estimate',
        'city_fact',
        'airport_facility',
        'airport_fact',
        'page_editorial_content'
      )
    ),

  CONSTRAINT raw_base_data_records_source_key_check
    CHECK (
      source_key = btrim(source_key)
      AND char_length(source_key) BETWEEN 1 AND 160
    ),

  CONSTRAINT raw_base_data_records_payload_object_check
    CHECK (jsonb_typeof(payload) = 'object'),

  CONSTRAINT raw_base_data_records_validation_state_check
    CHECK (validation_state IN ('pending', 'valid', 'invalid'))
);

CREATE INDEX raw_base_data_records_batch_idx
ON admin.raw_base_data_records USING btree (batch_id);

REVOKE ALL ON TABLE admin.raw_base_data_records FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.raw_base_data_records TO service_role;
