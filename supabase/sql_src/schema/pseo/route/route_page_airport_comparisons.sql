-- Table: public.route_page_airport_comparisons
-- Feature: Route pSEO
-- Purpose: Store reviewed origin/destination airport comparison facts.

CREATE TABLE public.route_page_airport_comparisons (
  id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  route_page_id       UUID          NOT NULL REFERENCES public.route_pages (id) ON DELETE CASCADE,
  airport_id          UUID          NOT NULL REFERENCES public.airports (id),
  endpoint_role       TEXT          NOT NULL,
  transfer_summary    TEXT          NOT NULL,
  duration_min_minutes INTEGER      NULL,
  duration_max_minutes INTEGER      NULL,
  price_min           NUMERIC(12,2) NULL,
  price_max           NUMERIC(12,2) NULL,
  currency_code       TEXT          NULL,
  primary_source_url  TEXT          NOT NULL,
  last_verified_at    TIMESTAMPTZ   NOT NULL,
  display_order       SMALLINT      NOT NULL,
  status              TEXT          NOT NULL DEFAULT 'draft',
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT route_page_airports_identity_key UNIQUE (route_page_id, airport_id, endpoint_role),
  CONSTRAINT route_page_airports_role_check CHECK (endpoint_role IN ('origin', 'destination')),
  CONSTRAINT route_page_airports_status_check CHECK (status IN ('draft', 'review', 'published'))
);

ALTER TABLE public.route_page_airport_comparisons ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.route_page_airport_comparisons FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_page_airport_comparisons TO service_role;

