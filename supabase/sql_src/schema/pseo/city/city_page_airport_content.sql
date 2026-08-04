-- Table: public.city_page_airport_content
-- Feature: Interactive pSEO
-- Purpose: Store reviewed airport-hub copy and ordering for one localized city page.
-- Responsibilities: Keep locale-specific editorial content outside normalized airport facts.

CREATE TABLE public.city_page_airport_content (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  city_page_id   UUID         NOT NULL REFERENCES public.city_pages (id) ON DELETE CASCADE,
  airport_id     UUID         NOT NULL REFERENCES public.airports (id),
  hub_label      TEXT         NOT NULL,
  description    TEXT         NOT NULL,
  display_order  SMALLINT     NOT NULL,
  status         TEXT         NOT NULL DEFAULT 'draft',
  reviewed_at    TIMESTAMPTZ  NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT city_page_airport_content_page_airport_key
    UNIQUE (city_page_id, airport_id),

  CONSTRAINT city_page_airport_content_page_order_key
    UNIQUE (city_page_id, display_order),

  CONSTRAINT city_page_airport_content_hub_label_check
    CHECK (
      hub_label = btrim(hub_label)
      AND char_length(hub_label) BETWEEN 2 AND 40
    ),

  CONSTRAINT city_page_airport_content_description_check
    CHECK (
      description = btrim(description)
      AND char_length(description) BETWEEN 20 AND 1000
    ),

  CONSTRAINT city_page_airport_content_order_check
    CHECK (display_order > 0),

  CONSTRAINT city_page_airport_content_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

CREATE INDEX city_page_airport_content_page_status_order_idx
ON public.city_page_airport_content USING btree (
  city_page_id,
  status,
  display_order
);

ALTER TABLE public.city_page_airport_content ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.city_page_airport_content FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.city_page_airport_content TO service_role;
