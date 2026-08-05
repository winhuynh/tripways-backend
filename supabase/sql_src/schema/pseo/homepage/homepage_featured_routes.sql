-- Table: public.homepage_featured_routes
-- Feature: Homepage pSEO
-- Purpose: Store reviewed featured route selections backed by canonical city identities.

CREATE TABLE public.homepage_featured_routes (
  id                      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  homepage_page_id        UUID          NOT NULL REFERENCES public.homepage_pages (id) ON DELETE CASCADE,
  origin_city_id          UUID          NOT NULL REFERENCES public.cities (id),
  destination_city_id     UUID          NOT NULL REFERENCES public.cities (id),
  origin_airport_id       UUID          NULL REFERENCES public.airports (id),
  destination_airport_id  UUID          NULL REFERENCES public.airports (id),
  stop_bucket             TEXT          NOT NULL,
  duration_min_minutes    INTEGER       NOT NULL,
  duration_max_minutes    INTEGER       NOT NULL,
  route_path              TEXT          NOT NULL,
  display_order           SMALLINT      NOT NULL,
  status                  TEXT          NOT NULL DEFAULT 'draft',
  reviewed_at             TIMESTAMPTZ   NULL,
  data_version            UUID          NOT NULL,
  created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT homepage_featured_routes_order_key
    UNIQUE (homepage_page_id, display_order, data_version),

  CONSTRAINT homepage_featured_routes_direction_check
    CHECK (origin_city_id <> destination_city_id),

  CONSTRAINT homepage_featured_routes_stops_check
    CHECK (stop_bucket IN ('direct', 'one_stop', 'two_stops', 'three_stops')),

  CONSTRAINT homepage_featured_routes_duration_check
    CHECK (duration_min_minutes > 0 AND duration_max_minutes >= duration_min_minutes),

  CONSTRAINT homepage_featured_routes_path_check
    CHECK (route_path ~ '^/[a-z0-9]+(?:[-/][a-z0-9]+)*$'),

  CONSTRAINT homepage_featured_routes_order_check
    CHECK (display_order > 0),

  CONSTRAINT homepage_featured_routes_status_check
    CHECK (status IN ('draft', 'review', 'published'))
);

ALTER TABLE public.homepage_featured_routes ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.homepage_featured_routes FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.homepage_featured_routes TO service_role;
