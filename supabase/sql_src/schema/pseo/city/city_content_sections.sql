-- Table: public.city_content_sections
-- Feature: City pSEO
-- Purpose: Store bounded reviewed editorial sections for one City Hub.

CREATE TABLE public.city_content_sections (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  city_page_id        UUID         NOT NULL REFERENCES public.city_pages (id) ON DELETE CASCADE,
  locale              TEXT         NOT NULL,
  section_type        TEXT         NOT NULL,
  heading             TEXT         NOT NULL,
  body                TEXT         NOT NULL,
  display_order       SMALLINT     NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  primary_source_url  TEXT         NULL,
  last_verified_at    TIMESTAMPTZ  NULL,
  reviewed_at         TIMESTAMPTZ  NULL,
  data_version        UUID         NOT NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT city_content_sections_order_key
    UNIQUE (city_page_id, locale, display_order, data_version),

  CONSTRAINT city_content_sections_type_check
    CHECK (section_type IN ('route_context', 'airport_context', 'travel_context', 'methodology', 'data_disclaimer')),

  CONSTRAINT city_content_sections_status_check
    CHECK (status IN ('draft', 'review', 'published')),

  CONSTRAINT city_content_sections_order_check
    CHECK (display_order > 0)
);

ALTER TABLE public.city_content_sections ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.city_content_sections FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.city_content_sections TO service_role;
