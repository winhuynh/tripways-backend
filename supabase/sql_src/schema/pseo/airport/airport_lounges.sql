-- Table: public.airport_lounges
-- Feature: Interactive pSEO
-- Purpose: Store reviewed lounge summaries relevant to flight planning.

CREATE TABLE public.airport_lounges (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_page_id     UUID         NOT NULL REFERENCES public.airport_pages (id) ON DELETE CASCADE,
  name                TEXT         NOT NULL,
  location_summary    TEXT         NOT NULL,
  location_type       TEXT         NOT NULL DEFAULT 'unknown',
  access_summary      TEXT         NOT NULL,
  operating_hours_summary TEXT     NULL,
  amenities           TEXT[]       NOT NULL DEFAULT '{}'::TEXT[],
  estimated_price_min NUMERIC(12,2) NULL,
  estimated_price_max NUMERIC(12,2) NULL,
  currency_code       TEXT         NULL,
  affiliate_url       TEXT         NULL,
  official_url        TEXT         NULL,
  primary_source_url  TEXT         NOT NULL,
  last_verified_at    TIMESTAMPTZ  NOT NULL,
  display_order       SMALLINT     NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_lounges_page_name_key
    UNIQUE (airport_page_id, name),

  CONSTRAINT airport_lounges_page_order_key
    UNIQUE (airport_page_id, display_order),

  CONSTRAINT airport_lounges_location_type_check
    CHECK (location_type IN ('airside', 'landside', 'unknown')),

  CONSTRAINT airport_lounges_amenities_check
    CHECK (amenities <@ ARRAY['wifi', 'food', 'drinks', 'showers', 'rest_area', 'work_area']::TEXT[]),

  CONSTRAINT airport_lounges_price_check
    CHECK (
      (estimated_price_min IS NULL AND estimated_price_max IS NULL AND currency_code IS NULL)
      OR (
        estimated_price_min >= 0
        AND estimated_price_max >= estimated_price_min
        AND currency_code ~ '^[A-Z]{3}$'
      )
    ),

  CONSTRAINT airport_lounges_order_check
    CHECK (display_order > 0),

  CONSTRAINT airport_lounges_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

CREATE INDEX airport_lounges_page_status_order_idx
ON public.airport_lounges USING btree (airport_page_id, status, display_order);

ALTER TABLE public.airport_lounges ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_lounges FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_lounges TO service_role;
