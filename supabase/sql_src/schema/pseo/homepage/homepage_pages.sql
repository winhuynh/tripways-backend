-- Table: public.homepage_pages
-- Feature: Homepage pSEO
-- Purpose: Store reviewed homepage SEO and primary editorial content by locale.

CREATE TABLE public.homepage_pages (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  pseo_page_id         UUID         NOT NULL UNIQUE REFERENCES public.pseo_pages (id) ON DELETE CASCADE,
  locale               TEXT         NOT NULL UNIQUE,
  h1                   TEXT         NOT NULL,
  subheadline          TEXT         NOT NULL,
  intro                TEXT         NOT NULL,
  seo_title            TEXT         NOT NULL,
  meta_description     TEXT         NOT NULL,
  status               TEXT         NOT NULL DEFAULT 'draft',
  is_indexable         BOOLEAN      NOT NULL DEFAULT FALSE,
  noindex_reason       TEXT         NULL,
  content_reviewed_at  TIMESTAMPTZ  NULL,
  source_freshness_at  TIMESTAMPTZ  NULL,
  data_version         UUID         NULL,
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT homepage_pages_locale_check
    CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

  CONSTRAINT homepage_pages_status_check
    CHECK (status IN ('draft', 'review', 'published', 'archived')),

  CONSTRAINT homepage_pages_indexability_check
    CHECK (
      (is_indexable = TRUE AND status = 'published' AND noindex_reason IS NULL)
      OR (is_indexable = FALSE AND noindex_reason IS NOT NULL)
    )
);

ALTER TABLE public.homepage_pages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.homepage_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.homepage_pages TO service_role;
