-- Table: public.homepage_featured_origins
-- Feature: Homepage pSEO
-- Purpose: Store reviewed origin cards without duplicating aviation identity facts.

CREATE TABLE public.homepage_featured_origins (
  id                        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  homepage_page_id          UUID         NOT NULL REFERENCES public.homepage_pages (id) ON DELETE CASCADE,
  city_id                   UUID         NULL REFERENCES public.cities (id),
  airport_id                UUID         NULL REFERENCES public.airports (id),
  title                     TEXT         NOT NULL,
  summary                   TEXT         NOT NULL,
  direct_destination_count  INTEGER      NOT NULL,
  image_path                TEXT         NULL,
  display_order             SMALLINT     NOT NULL,
  status                    TEXT         NOT NULL DEFAULT 'draft',
  primary_source_url        TEXT         NULL,
  last_verified_at          TIMESTAMPTZ  NULL,
  reviewed_at               TIMESTAMPTZ  NULL,
  data_version              UUID         NOT NULL,
  created_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT homepage_featured_origins_order_key
    UNIQUE (homepage_page_id, display_order, data_version),

  CONSTRAINT homepage_featured_origins_identity_check
    CHECK ((city_id IS NOT NULL)::INTEGER + (airport_id IS NOT NULL)::INTEGER = 1),

  CONSTRAINT homepage_featured_origins_count_check
    CHECK (direct_destination_count >= 0),

  CONSTRAINT homepage_featured_origins_image_check
    CHECK (image_path IS NULL OR (image_path !~* '^[a-z][a-z0-9+.-]*://' AND image_path !~ '\.\.')),

  CONSTRAINT homepage_featured_origins_order_check
    CHECK (display_order > 0),

  CONSTRAINT homepage_featured_origins_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

ALTER TABLE public.homepage_featured_origins ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.homepage_featured_origins FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.homepage_featured_origins TO service_role;
