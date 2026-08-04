-- Table: public.city_facts
-- Feature: City pSEO
-- Purpose: Store reviewed, cited, structured city knowledge.

CREATE TABLE public.city_facts (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id             UUID         NOT NULL REFERENCES public.cities (id),
  locale              TEXT         NOT NULL,
  fact_type           TEXT         NOT NULL,
  title               TEXT         NOT NULL,
  body                TEXT         NOT NULL,
  structured_value    JSONB        NULL,
  primary_source_url  TEXT         NOT NULL,
  last_verified_at    TIMESTAMPTZ  NOT NULL,
  valid_from          DATE         NULL,
  valid_to            DATE         NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  data_version        UUID         NOT NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT city_facts_identity_key UNIQUE (city_id, locale, fact_type, data_version),
  CONSTRAINT city_facts_type_check CHECK (fact_type IN ('currency', 'language', 'timezone', 'entry_guidance', 'climate', 'local_transport', 'travel_tip')),
  CONSTRAINT city_facts_status_check CHECK (status IN ('draft', 'review', 'published')),
  CONSTRAINT city_facts_validity_check CHECK ((valid_from IS NULL) = (valid_to IS NULL))
);

CREATE INDEX city_facts_page_idx ON public.city_facts USING btree (city_id, locale, status, fact_type);
ALTER TABLE public.city_facts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.city_facts FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.city_facts TO service_role;

