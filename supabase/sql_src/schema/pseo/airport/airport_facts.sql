-- Table: public.airport_facts
-- Feature: Airport pSEO
-- Purpose: Store reviewed, cited, structured airport knowledge.

CREATE TABLE public.airport_facts (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_id          UUID         NOT NULL REFERENCES public.airports (id),
  locale              TEXT         NOT NULL,
  fact_type           TEXT         NOT NULL,
  title               TEXT         NOT NULL,
  body                TEXT         NOT NULL,
  structured_value    JSONB        NULL,
  primary_source_url  TEXT         NOT NULL,
  last_verified_at    TIMESTAMPTZ  NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  data_version        UUID         NOT NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_facts_identity_key UNIQUE (airport_id, locale, fact_type, data_version),
  CONSTRAINT airport_facts_type_check CHECK (fact_type IN ('timezone', 'connection', 'accessibility', 'check_in', 'security_guidance', 'airport_tip')),
  CONSTRAINT airport_facts_status_check CHECK (status IN ('draft', 'review', 'published'))
);

CREATE INDEX airport_facts_page_idx ON public.airport_facts USING btree (airport_id, locale, status, fact_type);
ALTER TABLE public.airport_facts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.airport_facts FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_facts TO service_role;
