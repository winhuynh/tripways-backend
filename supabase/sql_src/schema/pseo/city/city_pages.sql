-- Table: public.city_pages
-- Feature: Interactive pSEO
-- Purpose: Store one aggregate source document per localized city page.

CREATE TABLE public.city_pages (
  id                        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  pseo_page_id              UUID         NOT NULL UNIQUE REFERENCES public.pseo_pages (id),
  city_id                   UUID         NOT NULL REFERENCES public.cities (id),
  locale                    TEXT         NOT NULL,
  route_direction           TEXT         NOT NULL DEFAULT 'outbound',
  primary_airport_id        UUID         NULL REFERENCES public.airports (id),
  content JSONB NOT NULL DEFAULT '{}'::jsonb,
  content_reviewed_at       TIMESTAMPTZ  NULL,
  created_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT city_pages_city_locale_key
    UNIQUE (city_id, locale, route_direction),

  CONSTRAINT city_pages_direction_check
    CHECK (route_direction IN ('outbound', 'inbound')),

  CONSTRAINT city_pages_locale_check
    CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

  CONSTRAINT city_pages_content_check CHECK (jsonb_typeof(content) = 'object')
);

ALTER TABLE public.city_pages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.city_pages FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.city_pages TO service_role;
