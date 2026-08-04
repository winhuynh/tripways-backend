-- Table: public.city_page_faqs
-- Feature: Interactive pSEO
-- Purpose: Store ordered, reviewed FAQ content for city pages.
-- Responsibilities: Distinguish editorial, data-backed, and hybrid answers.

CREATE TABLE public.city_page_faqs (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  city_page_id   UUID         NOT NULL REFERENCES public.city_pages (id) ON DELETE CASCADE,
  question       TEXT         NOT NULL,
  answer         TEXT         NOT NULL,
  answer_type    TEXT         NOT NULL,
  display_order  SMALLINT     NOT NULL,
  status         TEXT         NOT NULL DEFAULT 'draft',
  reviewed_at    TIMESTAMPTZ  NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT city_page_faqs_page_order_key
    UNIQUE (city_page_id, display_order),

  CONSTRAINT city_page_faqs_page_question_key
    UNIQUE (city_page_id, question),

  CONSTRAINT city_page_faqs_question_check
    CHECK (
      question = btrim(question)
      AND char_length(question) BETWEEN 5 AND 240
    ),

  CONSTRAINT city_page_faqs_answer_check
    CHECK (
      answer = btrim(answer)
      AND char_length(answer) BETWEEN 10 AND 2000
    ),

  CONSTRAINT city_page_faqs_answer_type_check
    CHECK (answer_type IN ('editorial', 'data_backed', 'hybrid')),

  CONSTRAINT city_page_faqs_order_check
    CHECK (display_order > 0),

  CONSTRAINT city_page_faqs_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

CREATE INDEX city_page_faqs_page_status_order_idx
ON public.city_page_faqs USING btree (
  city_page_id,
  status,
  display_order
);

ALTER TABLE public.city_page_faqs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.city_page_faqs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.city_page_faqs TO service_role;
