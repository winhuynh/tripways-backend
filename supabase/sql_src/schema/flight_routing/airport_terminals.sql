-- Table: public.airport_terminals
-- Feature: Airport Knowledge
-- Purpose: Store provider-neutral terminal identities and review state.

CREATE TABLE public.airport_terminals (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_id        UUID         NOT NULL REFERENCES public.airports (id),
  code              TEXT         NOT NULL,
  name              TEXT         NOT NULL,
  status            TEXT         NOT NULL DEFAULT 'unknown',
  source_id         UUID         NOT NULL REFERENCES admin.data_sources (id),
  source_record_id  TEXT         NOT NULL,
  last_verified_at  TIMESTAMPTZ  NOT NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_terminals_airport_code_key UNIQUE (airport_id, code),
  CONSTRAINT airport_terminals_source_record_key UNIQUE (source_id, source_record_id),
  CONSTRAINT airport_terminals_status_check CHECK (status IN ('active', 'inactive', 'unknown'))
);

ALTER TABLE public.airport_terminals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.airport_terminals FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_terminals TO service_role;

