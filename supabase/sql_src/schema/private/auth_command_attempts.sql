-- Table: private.auth_command_attempts
-- Feature: User authentication
-- Purpose: Persist bounded counters for sensitive account-command rate limits.
-- Responsibilities: Store only hashed subjects, actions, fixed windows, and attempt counts.
-- Notes: Raw user IDs and IP addresses are never persisted.

create table private.auth_command_attempts (
  subject_hash text not null,
  action text not null,
  window_started_at timestamptz not null,
  attempt_count integer not null,
  updated_at timestamptz not null default now(),
  constraint auth_command_attempts_pkey
    primary key (subject_hash, action, window_started_at),
  constraint auth_command_attempts_subject_hash_check
    check (subject_hash ~ '^[0-9a-f]{64}$'),
  constraint auth_command_attempts_action_check
    check (action in ('password_changed', 'password_recovered', 'email_changed', 'delete_account')),
  constraint auth_command_attempts_count_check
    check (attempt_count > 0)
);

revoke all on table private.auth_command_attempts from public, anon, authenticated;
grant usage on schema private to service_role;
grant select, insert, update, delete on table private.auth_command_attempts to service_role;
