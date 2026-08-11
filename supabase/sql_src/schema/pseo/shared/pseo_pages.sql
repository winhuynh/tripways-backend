-- Table: public.pseo_pages
-- Feature: Interactive pSEO
-- Purpose: Register canonical URLs, publication state, and sitemap eligibility.
-- Responsibilities: Provide stable page identity and database-owned indexability metadata.

CREATE TABLE public.pseo_pages (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  page_type            TEXT         NOT NULL,
  entity_key           TEXT         NOT NULL,
  locale               TEXT         NOT NULL,
  canonical_path       TEXT         NOT NULL,
  display_title        TEXT         NOT NULL,
  status               TEXT         NOT NULL DEFAULT 'draft',
  is_indexable         BOOLEAN      NOT NULL DEFAULT FALSE,
  noindex_reason       TEXT         NULL,
  data_version         UUID         NULL REFERENCES public.publication_versions (id),
  content_updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  source_freshness_at  TIMESTAMPTZ  NULL,
  generated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT pseo_pages_entity_locale_key
    UNIQUE (page_type, entity_key, locale),

  CONSTRAINT pseo_pages_canonical_locale_key
    UNIQUE (canonical_path, locale),

  CONSTRAINT pseo_pages_type_check
    CHECK (
      page_type IN (
        'city',
        'airport',
        'city_route',
        'airline_city',
        'country_route',
        'guide'
      )
    ),

  CONSTRAINT pseo_pages_entity_key_check
    CHECK (entity_key ~ '^[a-z0-9]+(?:[-:][a-z0-9]+)*$'),

  CONSTRAINT pseo_pages_locale_check
    CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

  CONSTRAINT pseo_pages_canonical_path_check
    CHECK (canonical_path = '/' OR canonical_path ~ '^/[a-z0-9]+(?:[-/][a-z0-9]+)*$'),

  CONSTRAINT pseo_pages_title_check
    CHECK (
      display_title = btrim(display_title)
      AND char_length(display_title) BETWEEN 1 AND 160
    ),

  CONSTRAINT pseo_pages_status_check
    CHECK (status IN ('draft', 'review', 'published', 'archived')),

  CONSTRAINT pseo_pages_indexability_check
    CHECK (
      (is_indexable = TRUE AND status = 'published' AND noindex_reason IS NULL)
      OR
      (is_indexable = FALSE AND noindex_reason IS NOT NULL)
    )
);

CREATE INDEX pseo_pages_sitemap_idx
ON public.pseo_pages USING btree (
  locale,
  page_type,
  canonical_path
)
WHERE is_indexable = TRUE AND status = 'published';

ALTER TABLE public.pseo_pages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.pseo_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.pseo_pages TO service_role;
