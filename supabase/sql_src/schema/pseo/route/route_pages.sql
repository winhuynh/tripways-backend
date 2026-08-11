-- Table: public.route_pages
-- Feature: Route pSEO
-- Purpose: Store reviewed city-pair Route Page editorial content.

CREATE TABLE public.route_pages (
  id                         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  pseo_page_id               UUID         NOT NULL UNIQUE REFERENCES public.pseo_pages (id),
  origin_city_id             UUID         NOT NULL REFERENCES public.cities (id),
  destination_city_id        UUID         NOT NULL REFERENCES public.cities (id),
  locale                     TEXT         NOT NULL,
  h1                         TEXT         NOT NULL,
  subheadline                TEXT         NOT NULL,
  seo_title                  TEXT         NOT NULL,
  meta_description           TEXT         NOT NULL,
  intro                      TEXT         NOT NULL,
  content_reviewed_at        TIMESTAMPTZ  NULL,
  created_at                 TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT route_pages_market_key UNIQUE (origin_city_id, destination_city_id, locale),
  CONSTRAINT route_pages_direction_check CHECK (origin_city_id <> destination_city_id),
  CONSTRAINT route_pages_locale_check CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$')
);
ALTER TABLE public.route_pages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_pages TO service_role;
