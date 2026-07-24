-- Table: private.auth_command_attempts
-- Feature: User authentication
-- Purpose: Persist bounded counters for sensitive account-command rate limits.
-- Responsibilities: Store only hashed subjects, actions, fixed windows, and attempt counts.
-- Notes: Raw user IDs and IP addresses are never persisted.

CREATE TABLE private.auth_command_attempts (
  subject_hash       TEXT         NOT NULL,
  action             TEXT         NOT NULL,
  window_started_at  TIMESTAMPTZ  NOT NULL,
  attempt_count      INTEGER      NOT NULL,
  updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT auth_command_attempts_pkey
    PRIMARY KEY (subject_hash, action, window_started_at),

  CONSTRAINT auth_command_attempts_subject_hash_check
    CHECK (subject_hash ~ '^[0-9a-f]{64}$'),

  CONSTRAINT auth_command_attempts_action_check
    CHECK (action IN ('password_changed', 'password_recovered', 'email_changed', 'delete_account')),

  CONSTRAINT auth_command_attempts_count_check
    CHECK (attempt_count > 0)
);

REVOKE ALL ON TABLE private.auth_command_attempts FROM public, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private.auth_command_attempts TO service_role;
