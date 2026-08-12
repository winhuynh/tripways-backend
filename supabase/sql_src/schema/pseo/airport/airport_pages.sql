-- Table: public.airport_pages
-- Feature: Interactive pSEO
-- Purpose: Store one aggregate source document per localized airport page.

CREATE TABLE public.airport_pages (
  id                          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  pseo_page_id                UUID         NOT NULL UNIQUE REFERENCES public.pseo_pages (id),
  airport_id                  UUID         NOT NULL REFERENCES public.airports (id),
  locale                      TEXT         NOT NULL,
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  content_reviewed_at         TIMESTAMPTZ  NULL,
  created_at                  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_pages_airport_locale_key
    UNIQUE (airport_id, locale),

  CONSTRAINT airport_pages_locale_check
    CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

  CONSTRAINT airport_pages_content_check CHECK (jsonb_typeof(content) = 'object')
);

ALTER TABLE public.airport_pages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_pages TO service_role;
