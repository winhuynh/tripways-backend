-- Table: public.route_page_faqs
-- Feature: Route pSEO
-- Purpose: Store reviewed ordered Route Page FAQs.

CREATE TABLE public.route_page_faqs (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  route_page_id  UUID         NOT NULL REFERENCES public.route_pages (id) ON DELETE CASCADE,
  locale         TEXT         NOT NULL DEFAULT 'en-GB',
  question       TEXT         NOT NULL,
  answer         TEXT         NOT NULL,
  answer_type    TEXT         NOT NULL,
  display_order  SMALLINT     NOT NULL,
  status         TEXT         NOT NULL DEFAULT 'draft',
  reviewed_at    TIMESTAMPTZ  NULL,
  primary_source_url TEXT     NULL,
  last_verified_at TIMESTAMPTZ NULL,
  data_version   UUID         NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT route_page_faqs_order_key UNIQUE (route_page_id, locale, display_order),
  CONSTRAINT route_page_faqs_question_key UNIQUE (route_page_id, locale, question),
  CONSTRAINT route_page_faqs_locale_check CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),
  CONSTRAINT route_page_faqs_type_check CHECK (answer_type IN ('editorial', 'data_backed', 'hybrid')),
  CONSTRAINT route_page_faqs_status_check CHECK (status IN ('draft', 'review', 'published'))
);

ALTER TABLE public.route_page_faqs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_page_faqs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_page_faqs TO service_role;
