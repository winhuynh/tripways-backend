-- Table: public.airport_pages
-- Feature: Interactive pSEO
-- Purpose: Store reviewed airport-page editorial content.
-- Responsibilities: Link editorial content to the canonical pSEO registry and normalized airport.

CREATE TABLE public.airport_pages (
  id                          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  pseo_page_id                UUID         NOT NULL UNIQUE REFERENCES public.pseo_pages (id),
  airport_id                  UUID         NOT NULL REFERENCES public.airports (id),
  locale                      TEXT         NOT NULL,
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
  content_reviewed_at         TIMESTAMPTZ  NULL,
  created_at                  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_pages_airport_locale_key
    UNIQUE (airport_id, locale),

  CONSTRAINT airport_pages_locale_check
    CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

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

  CONSTRAINT airport_pages_city_distance_check
    CHECK (
      city_distance_km IS NULL
      OR city_distance_km >= 0
    )
);

ALTER TABLE public.airport_pages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_pages TO service_role;
