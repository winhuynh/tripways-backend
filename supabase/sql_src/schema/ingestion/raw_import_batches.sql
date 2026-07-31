-- Table: private.raw_import_batches
-- Feature: Base Data Ingestion
-- Purpose: Record immutable provider batch receipts before canonical publication.
-- Responsibilities: Preserve source provenance, checksum idempotency, and batch lifecycle state.

CREATE TABLE private.raw_import_batches (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id         UUID         NOT NULL REFERENCES admin.data_sources (id),
  provider_version  TEXT         NOT NULL,
  checksum          TEXT         NOT NULL,
  idempotency_key   TEXT         NOT NULL,
  received_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
  source_time       TIMESTAMPTZ  NULL,
  status            TEXT         NOT NULL DEFAULT 'received',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT raw_import_batches_source_checksum_key
    UNIQUE (source_id, checksum),

  CONSTRAINT raw_import_batches_source_idempotency_key
    UNIQUE (source_id, idempotency_key),

  CONSTRAINT raw_import_batches_provider_version_check
    CHECK (
      provider_version = btrim(provider_version)
      AND char_length(provider_version) BETWEEN 1 AND 40
    ),

  CONSTRAINT raw_import_batches_checksum_check
    CHECK (checksum ~ '^[a-f0-9]{64}$'),

  CONSTRAINT raw_import_batches_idempotency_key_check
    CHECK (
      idempotency_key = btrim(idempotency_key)
      AND char_length(idempotency_key) BETWEEN 8 AND 128
    ),

  CONSTRAINT raw_import_batches_status_check
    CHECK (status IN ('received', 'validated', 'published', 'rejected'))
);

CREATE INDEX raw_import_batches_source_received_idx
ON private.raw_import_batches USING btree (source_id, received_at DESC);

REVOKE ALL ON TABLE private.raw_import_batches FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.raw_import_batches TO service_role;
