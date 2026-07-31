-- Table: admin.ingestion_runs
-- Feature: Base Data Ingestion
-- Purpose: Record bounded operational outcomes for ingestion attempts.
-- Responsibilities: Track atomic publication actions, counts, status, and stable errors.

CREATE TABLE admin.ingestion_runs (
  id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id           UUID         NOT NULL REFERENCES private.raw_import_batches (id),
  action             TEXT         NOT NULL,
  mode               TEXT         NOT NULL DEFAULT 'atomic',
  accepted_count     INTEGER      NOT NULL DEFAULT 0,
  rejected_count     INTEGER      NOT NULL DEFAULT 0,
  status             TEXT         NOT NULL DEFAULT 'started',
  stable_error_code  TEXT         NULL,
  started_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
  completed_at       TIMESTAMPTZ  NULL,
  created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ingestion_runs_mode_check
    CHECK (mode = 'atomic'),

  CONSTRAINT ingestion_runs_action_check
    CHECK (action IN ('validate', 'publish')),

  CONSTRAINT ingestion_runs_counts_check
    CHECK (accepted_count >= 0 AND rejected_count >= 0),

  CONSTRAINT ingestion_runs_status_check
    CHECK (status IN ('started', 'succeeded', 'failed')),

  CONSTRAINT ingestion_runs_error_code_check
    CHECK (
      stable_error_code IS NULL
      OR stable_error_code ~ '^ERR_[A-Z0-9_]+$'
    ),

  CONSTRAINT ingestion_runs_completion_check
    CHECK (
      (status = 'started' AND completed_at IS NULL)
      OR (status IN ('succeeded', 'failed') AND completed_at IS NOT NULL)
    )
);

CREATE INDEX ingestion_runs_batch_started_idx
ON admin.ingestion_runs USING btree (batch_id, started_at DESC);

REVOKE ALL ON TABLE admin.ingestion_runs FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.ingestion_runs TO service_role;
