-- Table: admin.ingestion_issues
-- Feature: Base Data Ingestion
-- Purpose: Record bounded validation and publication issues without retaining raw payloads.
-- Responsibilities: Associate stable issue codes and severities with an ingestion run.

CREATE TABLE admin.ingestion_issues (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id           UUID         NOT NULL REFERENCES admin.ingestion_runs (id) ON DELETE CASCADE,
  source_key_hash  TEXT         NULL,
  issue_code       TEXT         NOT NULL,
  severity         TEXT         NOT NULL,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ingestion_issues_source_key_hash_check
    CHECK (source_key_hash IS NULL OR source_key_hash ~ '^[a-f0-9]{64}$'),

  CONSTRAINT ingestion_issues_issue_code_check
    CHECK (issue_code ~ '^ERR_[A-Z0-9_]+$'),

  CONSTRAINT ingestion_issues_severity_check
    CHECK (severity IN ('warning', 'error'))
);

CREATE INDEX ingestion_issues_run_idx
ON admin.ingestion_issues USING btree (run_id);

REVOKE ALL ON TABLE admin.ingestion_issues FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE admin.ingestion_issues TO service_role;
