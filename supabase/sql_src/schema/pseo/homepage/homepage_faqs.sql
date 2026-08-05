-- Table: public.homepage_faqs
-- Feature: Homepage pSEO
-- Purpose: Store reviewed homepage FAQs independently from other page types.

CREATE TABLE public.homepage_faqs (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  homepage_page_id    UUID         NOT NULL REFERENCES public.homepage_pages (id) ON DELETE CASCADE,
  locale              TEXT         NOT NULL,
  question            TEXT         NOT NULL,
  answer              TEXT         NOT NULL,
  answer_type         TEXT         NOT NULL,
  display_order       SMALLINT     NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'draft',
  primary_source_url  TEXT         NULL,
  last_verified_at    TIMESTAMPTZ  NULL,
  reviewed_at         TIMESTAMPTZ  NULL,
  data_version        UUID         NOT NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT homepage_faqs_order_key
    UNIQUE (homepage_page_id, locale, display_order, data_version),

  CONSTRAINT homepage_faqs_question_key
    UNIQUE (homepage_page_id, locale, question, data_version),

  CONSTRAINT homepage_faqs_type_check
    CHECK (answer_type IN ('editorial', 'data_backed', 'hybrid')),

  CONSTRAINT homepage_faqs_status_check
    CHECK (status IN ('draft', 'review', 'published')),

  CONSTRAINT homepage_faqs_order_check
    CHECK (display_order > 0)
);

ALTER TABLE public.homepage_faqs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.homepage_faqs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.homepage_faqs TO service_role;
