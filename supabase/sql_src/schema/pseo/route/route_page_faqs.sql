-- Table: public.route_page_faqs
-- Feature: Route pSEO
-- Purpose: Store reviewed ordered Route Page FAQs.

CREATE TABLE public.route_page_faqs (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  route_page_id  UUID         NOT NULL REFERENCES public.route_pages (id) ON DELETE CASCADE,
  question       TEXT         NOT NULL,
  answer         TEXT         NOT NULL,
  answer_type    TEXT         NOT NULL,
  display_order  SMALLINT     NOT NULL,
  status         TEXT         NOT NULL DEFAULT 'draft',
  reviewed_at    TIMESTAMPTZ  NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT route_page_faqs_order_key UNIQUE (route_page_id, display_order),
  CONSTRAINT route_page_faqs_question_key UNIQUE (route_page_id, question),
  CONSTRAINT route_page_faqs_type_check CHECK (answer_type IN ('editorial', 'data_backed', 'hybrid')),
  CONSTRAINT route_page_faqs_status_check CHECK (status IN ('draft', 'review', 'published'))
);

ALTER TABLE public.route_page_faqs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_page_faqs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_page_faqs TO service_role;

