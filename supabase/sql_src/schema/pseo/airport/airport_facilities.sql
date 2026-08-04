-- Table: public.airport_facilities
-- Feature: Airport pSEO
-- Purpose: Store reviewed terminal or airport-wide facility guidance.

CREATE TABLE public.airport_facilities (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_id          UUID         NOT NULL REFERENCES public.airports (id),
  terminal_id         UUID         NULL REFERENCES public.airport_terminals (id),
  locale              TEXT         NOT NULL,
  category            TEXT         NOT NULL,
  name                TEXT         NOT NULL,
  summary             TEXT         NOT NULL,
  operating_hours     TEXT         NULL,
  primary_source_url  TEXT         NOT NULL,
  last_verified_at    TIMESTAMPTZ  NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  display_order       SMALLINT     NOT NULL,
  data_version        UUID         NOT NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_facilities_identity_key UNIQUE (airport_id, locale, name, data_version),
  CONSTRAINT airport_facilities_category_check CHECK (category IN ('wifi', 'food', 'shopping', 'shower', 'luggage', 'prayer', 'accessibility', 'family', 'medical', 'other')),
  CONSTRAINT airport_facilities_status_check CHECK (status IN ('draft', 'review', 'published')),
  CONSTRAINT airport_facilities_order_check CHECK (display_order > 0)
);

CREATE INDEX airport_facilities_page_idx ON public.airport_facilities USING btree (airport_id, locale, status, display_order);
ALTER TABLE public.airport_facilities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.airport_facilities FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_facilities TO service_role;

