-- Table: public.airport_page_faqs
-- Feature: Interactive pSEO
-- Purpose: Store ordered, reviewed FAQ content for airport pages.

CREATE TABLE public.airport_page_faqs (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_page_id  UUID         NOT NULL REFERENCES public.airport_pages (id) ON DELETE CASCADE,
  question         TEXT         NOT NULL,
  answer           TEXT         NOT NULL,
  answer_type      TEXT         NOT NULL,
  display_order    SMALLINT     NOT NULL,
  status           TEXT         NOT NULL DEFAULT 'draft',
  reviewed_at      TIMESTAMPTZ  NULL,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT airport_page_faqs_page_order_key
    UNIQUE (airport_page_id, display_order),

  CONSTRAINT airport_page_faqs_page_question_key
    UNIQUE (airport_page_id, question),

  CONSTRAINT airport_page_faqs_answer_type_check
    CHECK (answer_type IN ('editorial', 'data_backed', 'hybrid')),

  CONSTRAINT airport_page_faqs_order_check
    CHECK (display_order > 0),

  CONSTRAINT airport_page_faqs_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

CREATE INDEX airport_page_faqs_page_status_order_idx
ON public.airport_page_faqs USING btree (airport_page_id, status, display_order);

ALTER TABLE public.airport_page_faqs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_page_faqs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_page_faqs TO service_role;
