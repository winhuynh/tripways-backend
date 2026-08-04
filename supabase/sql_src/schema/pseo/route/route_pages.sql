-- Table: public.route_pages
-- Feature: Route pSEO
-- Purpose: Register reviewed city-pair Route Page content and publication facts.

CREATE TABLE public.route_pages (
  id                         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  pseo_page_id               UUID         NOT NULL UNIQUE REFERENCES public.pseo_pages (id),
  origin_city_id             UUID         NOT NULL REFERENCES public.cities (id),
  destination_city_id        UUID         NOT NULL REFERENCES public.cities (id),
  locale                     TEXT         NOT NULL,
  canonical_slug             TEXT         NOT NULL,
  h1                         TEXT         NOT NULL,
  subheadline                TEXT         NOT NULL,
  seo_title                  TEXT         NOT NULL,
  meta_description           TEXT         NOT NULL,
  intro                      TEXT         NOT NULL,
  direct_option_count        INTEGER      NOT NULL DEFAULT 0,
  indirect_option_count      INTEGER      NOT NULL DEFAULT 0,
  fastest_direct_minutes     INTEGER      NULL,
  fastest_indirect_minutes   INTEGER      NULL,
  status                     TEXT         NOT NULL DEFAULT 'draft',
  is_indexable               BOOLEAN      NOT NULL DEFAULT FALSE,
  noindex_reason             TEXT         NULL,
  content_reviewed_at        TIMESTAMPTZ  NULL,
  source_freshness_at        TIMESTAMPTZ  NULL,
  data_version               UUID         NULL,
  generated_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
  published_at               TIMESTAMPTZ  NULL,
  created_at                 TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT route_pages_market_key UNIQUE (origin_city_id, destination_city_id, locale),
  CONSTRAINT route_pages_slug_locale_key UNIQUE (canonical_slug, locale),
  CONSTRAINT route_pages_direction_check CHECK (origin_city_id <> destination_city_id),
  CONSTRAINT route_pages_status_check CHECK (status IN ('draft', 'review', 'published', 'archived')),
  CONSTRAINT route_pages_counts_check CHECK (direct_option_count >= 0 AND indirect_option_count >= 0),
  CONSTRAINT route_pages_indexability_check CHECK ((is_indexable = TRUE AND status = 'published' AND noindex_reason IS NULL) OR (is_indexable = FALSE AND noindex_reason IS NOT NULL))
);

CREATE INDEX route_pages_status_idx ON public.route_pages USING btree (status, is_indexable, locale);
ALTER TABLE public.route_pages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_pages TO service_role;

