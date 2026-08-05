-- Table: public.airport_pages
-- Feature: Interactive pSEO
-- Purpose: Store reviewed airport-page content and versioned route facts.
-- Responsibilities: Separate localized page lifecycle from normalized airport identity.

CREATE TABLE public.airport_pages (
  id                          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  pseo_page_id                UUID         NOT NULL UNIQUE REFERENCES public.pseo_pages (id),
  airport_id                  UUID         NOT NULL REFERENCES public.airports (id),
  locale                      TEXT         NOT NULL,
  canonical_slug              TEXT         NOT NULL,
  h1                          TEXT         NOT NULL,
  subheadline                 TEXT         NOT NULL,
  seo_title                   TEXT         NOT NULL,
  meta_description            TEXT         NOT NULL,
  og_title                    TEXT         NOT NULL,
  og_description              TEXT         NOT NULL,
  og_image_path               TEXT         NULL,
  intro                       TEXT         NOT NULL,
  orientation_summary         TEXT         NOT NULL,
  arrival_summary             TEXT         NOT NULL,
  departure_summary           TEXT         NOT NULL,
  primary_city_area_label     TEXT         NULL,
  city_distance_km            NUMERIC(8,2) NULL,
  status                      TEXT         NOT NULL DEFAULT 'draft',
  is_indexable                BOOLEAN      NOT NULL DEFAULT FALSE,
  noindex_reason              TEXT         NULL,
  content_reviewed_at         TIMESTAMPTZ  NULL,
  source_freshness_at         TIMESTAMPTZ  NULL,
  route_data_refreshed_at     TIMESTAMPTZ  NULL,
  data_version                UUID         NULL,
  generated_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),
  published_at                TIMESTAMPTZ  NULL,
  created_at                  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_pages_airport_locale_key
    UNIQUE (airport_id, locale),

  CONSTRAINT airport_pages_slug_locale_key
    UNIQUE (canonical_slug, locale),

  CONSTRAINT airport_pages_locale_check
    CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

  CONSTRAINT airport_pages_slug_check
    CHECK (canonical_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

  CONSTRAINT airport_pages_content_check
    CHECK (
      h1 = btrim(h1)
      AND subheadline = btrim(subheadline)
      AND seo_title = btrim(seo_title)
      AND meta_description = btrim(meta_description)
      AND og_title = btrim(og_title)
      AND og_description = btrim(og_description)
      AND intro = btrim(intro)
      AND orientation_summary = btrim(orientation_summary)
      AND arrival_summary = btrim(arrival_summary)
      AND departure_summary = btrim(departure_summary)
    ),

  CONSTRAINT airport_pages_status_check
    CHECK (status IN ('draft', 'review', 'published', 'archived')),

  CONSTRAINT airport_pages_indexability_check
    CHECK (
      (is_indexable = TRUE AND status = 'published' AND noindex_reason IS NULL)
      OR
      (is_indexable = FALSE AND noindex_reason IS NOT NULL)
    ),

  CONSTRAINT airport_pages_city_distance_check
    CHECK (
      city_distance_km IS NULL
      OR city_distance_km >= 0
    )
);

CREATE INDEX airport_pages_status_idx
ON public.airport_pages USING btree (status, is_indexable, locale);

ALTER TABLE public.airport_pages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_pages TO service_role;
