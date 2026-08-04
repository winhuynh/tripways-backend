-- Table: public.airport_access_options
-- Feature: Interactive pSEO
-- Purpose: Store reviewed ways to travel to and from an airport.

CREATE TABLE public.airport_access_options (
  id                       UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_page_id          UUID          NOT NULL REFERENCES public.airport_pages (id) ON DELETE CASCADE,
  access_type              TEXT          NOT NULL,
  name                     TEXT          NOT NULL,
  destination_label        TEXT          NOT NULL,
  summary                  TEXT          NOT NULL,
  duration_min_minutes     INTEGER       NULL,
  duration_max_minutes     INTEGER       NULL,
  price_min                NUMERIC(12,2) NULL,
  price_max                NUMERIC(12,2) NULL,
  currency_code            TEXT          NULL,
  operating_hours_summary  TEXT          NULL,
  booking_url              TEXT          NULL,
  primary_source_url       TEXT          NOT NULL,
  last_verified_at         TIMESTAMPTZ   NOT NULL,
  display_order            SMALLINT      NOT NULL,
  status                   TEXT          NOT NULL DEFAULT 'draft',
  created_at               TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT airport_access_options_page_order_key
    UNIQUE (airport_page_id, display_order),

  CONSTRAINT airport_access_options_type_check
    CHECK (access_type IN ('rail', 'metro', 'bus', 'taxi', 'ride_hailing', 'transfer', 'other')),

  CONSTRAINT airport_access_options_duration_check
    CHECK (
      (duration_min_minutes IS NULL) = (duration_max_minutes IS NULL)
      AND (
        duration_min_minutes IS NULL
        OR (duration_min_minutes > 0 AND duration_max_minutes >= duration_min_minutes)
      )
    ),

  CONSTRAINT airport_access_options_price_check
    CHECK (
      (price_min IS NULL AND price_max IS NULL AND currency_code IS NULL)
      OR (
        price_min >= 0
        AND price_max >= price_min
        AND currency_code ~ '^[A-Z]{3}$'
      )
    ),

  CONSTRAINT airport_access_options_order_check
    CHECK (display_order > 0),

  CONSTRAINT airport_access_options_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

CREATE INDEX airport_access_options_page_status_order_idx
ON public.airport_access_options USING btree (airport_page_id, status, display_order);

ALTER TABLE public.airport_access_options ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_access_options FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_access_options TO service_role;
