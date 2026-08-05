-- Table: public.airport_content_sections
-- Feature: Airport pSEO
-- Purpose: Store bounded reviewed Airport Hub editorial sections.

CREATE TABLE public.airport_content_sections (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_page_id     UUID         NOT NULL REFERENCES public.airport_pages (id) ON DELETE CASCADE,
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

  CONSTRAINT airport_content_sections_order_key
    UNIQUE (airport_page_id, locale, display_order, data_version),

  CONSTRAINT airport_content_sections_type_check
    CHECK (
      section_type IN (
        'arrival_intro',
        'departure_intro',
        'transport_intro',
        'parking_cars_intro',
        'terminals_connections_intro',
        'facilities_intro',
        'methodology',
        'data_disclaimer'
      )
    ),

  CONSTRAINT airport_content_sections_status_check
    CHECK (status IN ('draft', 'review', 'published')),

  CONSTRAINT airport_content_sections_order_check
    CHECK (display_order > 0)
);

ALTER TABLE public.airport_content_sections ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_content_sections FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_content_sections TO service_role;
