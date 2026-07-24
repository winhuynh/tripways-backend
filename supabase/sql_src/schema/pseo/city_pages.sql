-- Table: public.city_pages
-- Feature: Interactive pSEO
-- Purpose: Store reviewed city-page content, metadata, facts, and publication state.
-- Responsibilities: Separate SEO lifecycle from normalized geographic identity.

CREATE TABLE public.city_pages (
  id                        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  pseo_page_id              UUID         NOT NULL UNIQUE REFERENCES public.pseo_pages (id),
  city_id                   UUID         NOT NULL REFERENCES public.cities (id),
  locale                    TEXT         NOT NULL,
  canonical_slug            TEXT         NOT NULL,
  h1                        TEXT         NOT NULL,
  subheadline               TEXT         NOT NULL,
  seo_title                 TEXT         NOT NULL,
  meta_description          TEXT         NOT NULL,
  og_title                  TEXT         NOT NULL,
  og_description            TEXT         NOT NULL,
  og_image_path             TEXT         NULL,
  intro                     TEXT         NOT NULL,
  airport_summary           TEXT         NULL,
  status                    TEXT         NOT NULL DEFAULT 'draft',
  is_indexable              BOOLEAN      NOT NULL DEFAULT FALSE,
  noindex_reason            TEXT         NULL,
  primary_airport_id        UUID         NULL REFERENCES public.airports (id),
  airport_count             INTEGER      NOT NULL DEFAULT 0,
  direct_destination_count  INTEGER      NOT NULL DEFAULT 0,
  direct_country_count      INTEGER      NOT NULL DEFAULT 0,
  airline_count             INTEGER      NOT NULL DEFAULT 0,
  shortest_route_minutes    INTEGER      NULL,
  longest_route_minutes     INTEGER      NULL,
  content_reviewed_at       TIMESTAMPTZ  NULL,
  source_freshness_at       TIMESTAMPTZ  NULL,
  data_version              UUID         NULL,
  generated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
  published_at              TIMESTAMPTZ  NULL,
  created_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT city_pages_city_locale_key
    UNIQUE (city_id, locale),

  CONSTRAINT city_pages_slug_locale_key
    UNIQUE (canonical_slug, locale),

  CONSTRAINT city_pages_locale_check
    CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

  CONSTRAINT city_pages_slug_check
    CHECK (canonical_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

  CONSTRAINT city_pages_content_check
    CHECK (
      h1 = btrim(h1)
      AND subheadline = btrim(subheadline)
      AND seo_title = btrim(seo_title)
      AND meta_description = btrim(meta_description)
      AND og_title = btrim(og_title)
      AND og_description = btrim(og_description)
      AND intro = btrim(intro)
    ),

  CONSTRAINT city_pages_status_check
    CHECK (status IN ('draft', 'review', 'published', 'archived')),

  CONSTRAINT city_pages_indexability_check
    CHECK (
      (is_indexable = TRUE AND status = 'published' AND noindex_reason IS NULL)
      OR
      (is_indexable = FALSE AND noindex_reason IS NOT NULL)
    ),

  CONSTRAINT city_pages_counts_check
    CHECK (
      airport_count >= 0
      AND direct_destination_count >= 0
      AND direct_country_count >= 0
      AND airline_count >= 0
    ),

  CONSTRAINT city_pages_duration_check
    CHECK (
      (shortest_route_minutes IS NULL) = (longest_route_minutes IS NULL)
      AND (
        shortest_route_minutes IS NULL
        OR (
          shortest_route_minutes > 0
          AND longest_route_minutes >= shortest_route_minutes
        )
      )
    )
);

CREATE INDEX city_pages_status_idx
ON public.city_pages USING btree (status, is_indexable, locale);

ALTER TABLE public.city_pages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.city_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.city_pages TO service_role;
