-- Table: public.route_page_travel_facts
-- Feature: Route pSEO
-- Purpose: Store reviewed, cited route-specific travel preparation facts.

CREATE TABLE public.route_page_travel_facts (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  route_page_id       UUID         NOT NULL REFERENCES public.route_pages (id) ON DELETE CASCADE,
  locale              TEXT         NOT NULL,
  fact_type           TEXT         NOT NULL,
  title               TEXT         NOT NULL,
  body                TEXT         NOT NULL,
  structured_value    JSONB        NULL,
  primary_source_url  TEXT         NOT NULL,
  last_verified_at    TIMESTAMPTZ  NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  display_order       SMALLINT     NOT NULL,
  data_version        UUID         NOT NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT route_page_travel_facts_identity_key UNIQUE (route_page_id, locale, fact_type, data_version),
  CONSTRAINT route_page_travel_facts_type_check CHECK (fact_type IN ('timezone', 'entry_guidance', 'transit_guidance', 'currency', 'language', 'arrival_transport', 'travel_tip')),
  CONSTRAINT route_page_travel_facts_status_check CHECK (status IN ('draft', 'review', 'published'))
);

ALTER TABLE public.route_page_travel_facts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_page_travel_facts FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_page_travel_facts TO service_role;

