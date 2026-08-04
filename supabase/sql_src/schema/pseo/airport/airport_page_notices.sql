-- Table: public.airport_page_notices
-- Feature: Interactive pSEO
-- Purpose: Store durable, reviewed airport planning notices.

CREATE TABLE public.airport_page_notices (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_page_id     UUID         NOT NULL REFERENCES public.airport_pages (id) ON DELETE CASCADE,
  notice_type         TEXT         NOT NULL,
  title               TEXT         NOT NULL,
  body                TEXT         NOT NULL,
  severity            TEXT         NOT NULL DEFAULT 'info',
  primary_source_url  TEXT         NOT NULL,
  last_verified_at    TIMESTAMPTZ  NOT NULL,
  display_order       SMALLINT     NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_page_notices_page_order_key
    UNIQUE (airport_page_id, display_order),

  CONSTRAINT airport_page_notices_type_check
    CHECK (notice_type IN ('general', 'access', 'connection', 'airport_confusion')),

  CONSTRAINT airport_page_notices_severity_check
    CHECK (severity IN ('info', 'important')),

  CONSTRAINT airport_page_notices_order_check
    CHECK (display_order > 0),

  CONSTRAINT airport_page_notices_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

CREATE INDEX airport_page_notices_page_status_order_idx
ON public.airport_page_notices USING btree (airport_page_id, status, display_order);

ALTER TABLE public.airport_page_notices ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_page_notices FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_page_notices TO service_role;
