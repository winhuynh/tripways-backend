-- Table: public.users
-- Feature: User
-- Purpose: Store the minimal application profile for an authenticated identity.
-- Responsibilities: Enforce profile shape, account state, ownership, and lifecycle linkage.
-- Notes: Email and credentials remain authoritative in auth.users.

CREATE TABLE public.users (
  user_id         UUID         PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  display_name    TEXT         NOT NULL,
  account_status  TEXT         NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT users_display_name_length_check
    CHECK (char_length(display_name) BETWEEN 2 AND 80),

  CONSTRAINT users_display_name_trimmed_check
    CHECK (display_name = btrim(display_name)),

  CONSTRAINT users_account_status_check
    CHECK (account_status = 'active')
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.users FROM anon, authenticated;
GRANT SELECT ON TABLE public.users TO authenticated, service_role;
GRANT INSERT, UPDATE, DELETE ON TABLE public.users TO service_role;

CREATE POLICY users_self_read
ON public.users
FOR SELECT
TO authenticated
USING (user_id = (SELECT auth.uid()));
