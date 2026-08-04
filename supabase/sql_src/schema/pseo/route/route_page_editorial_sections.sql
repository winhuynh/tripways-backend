-- Table: public.route_page_editorial_sections
-- Feature: Route pSEO
-- Purpose: Store bounded reviewed editorial sections without provider-specific layout fields.

CREATE TABLE public.route_page_editorial_sections (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  route_page_id  UUID         NOT NULL REFERENCES public.route_pages (id) ON DELETE CASCADE,
  locale         TEXT         NOT NULL,
  section_type   TEXT         NOT NULL,
  heading        TEXT         NOT NULL,
  body           TEXT         NOT NULL,
  display_order  SMALLINT     NOT NULL,
  status         TEXT         NOT NULL DEFAULT 'draft',
  reviewed_at    TIMESTAMPTZ  NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT route_page_editorial_order_key UNIQUE (route_page_id, locale, display_order),
  CONSTRAINT route_page_editorial_type_check CHECK (section_type IN ('direct', 'indirect', 'schedule', 'before_you_fly', 'alternatives', 'methodology', 'disclosure')),
  CONSTRAINT route_page_editorial_status_check CHECK (status IN ('draft', 'review', 'published'))
);

ALTER TABLE public.route_page_editorial_sections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_page_editorial_sections FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_page_editorial_sections TO service_role;
