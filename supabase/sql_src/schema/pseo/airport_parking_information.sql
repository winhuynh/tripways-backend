-- Table: public.airport_parking_information
-- Feature: Interactive pSEO
-- Purpose: Store one reviewed parking overview per localized airport page.

CREATE TABLE public.airport_parking_information (
  id                      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_page_id         UUID         NOT NULL UNIQUE REFERENCES public.airport_pages (id) ON DELETE CASCADE,
  summary                 TEXT         NOT NULL,
  short_stay_available    BOOLEAN      NULL,
  long_stay_available     BOOLEAN      NULL,
  reservation_available  BOOLEAN      NULL,
  shuttle_available      BOOLEAN      NULL,
  official_url            TEXT         NULL,
  primary_source_url      TEXT         NOT NULL,
  last_verified_at        TIMESTAMPTZ  NOT NULL,
  status                  TEXT         NOT NULL DEFAULT 'draft',
  created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_parking_information_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

CREATE INDEX airport_parking_information_page_status_idx
ON public.airport_parking_information USING btree (airport_page_id, status);

ALTER TABLE public.airport_parking_information ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_parking_information FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_parking_information TO service_role;
