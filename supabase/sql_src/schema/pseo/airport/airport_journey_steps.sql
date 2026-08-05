-- Table: public.airport_journey_steps
-- Feature: Airport Journey pSEO
-- Purpose: Store ordered, reviewed arrival and departure guidance.

CREATE TABLE public.airport_journey_steps (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_page_id     UUID         NOT NULL REFERENCES public.airport_pages (id) ON DELETE CASCADE,
  locale              TEXT         NOT NULL,
  journey_type        TEXT         NOT NULL,
  audience            TEXT         NOT NULL DEFAULT 'all',
  title               TEXT         NOT NULL,
  body                TEXT         NOT NULL,
  display_order       SMALLINT     NOT NULL,
  primary_source_url  TEXT         NOT NULL,
  last_verified_at    TIMESTAMPTZ  NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  data_version        UUID         NOT NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_journey_steps_order_key
    UNIQUE (airport_page_id, locale, journey_type, audience, display_order, data_version),

  CONSTRAINT airport_journey_steps_type_check
    CHECK (journey_type IN ('arrival', 'departure')),

  CONSTRAINT airport_journey_steps_audience_check
    CHECK (audience IN ('all', 'domestic', 'international')),

  CONSTRAINT airport_journey_steps_status_check
    CHECK (status IN ('draft', 'review', 'published')),

  CONSTRAINT airport_journey_steps_order_check
    CHECK (display_order > 0)
);

CREATE INDEX airport_journey_steps_page_status_order_idx
ON public.airport_journey_steps USING btree (
  airport_page_id,
  locale,
  journey_type,
  status,
  display_order
);

ALTER TABLE public.airport_journey_steps ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_journey_steps FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_journey_steps TO service_role;
