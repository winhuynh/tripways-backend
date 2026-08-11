-- Table: public.homepage_statistics
-- Feature: Homepage
-- Purpose: Store one bounded public coverage snapshot for the current publication.

CREATE TABLE public.homepage_statistics (
  singleton_key       BOOLEAN      PRIMARY KEY DEFAULT TRUE,
  city_count          INTEGER      NOT NULL,
  airport_count       INTEGER      NOT NULL,
  direct_route_count  INTEGER      NOT NULL,
  data_version        UUID         NOT NULL REFERENCES public.publication_versions (id),
  generated_at        TIMESTAMPTZ  NOT NULL,

  CONSTRAINT homepage_statistics_singleton_check
    CHECK (singleton_key = TRUE),

  CONSTRAINT homepage_statistics_counts_check
    CHECK (city_count >= 0 AND airport_count >= 0 AND direct_route_count >= 0)
);

ALTER TABLE public.homepage_statistics ENABLE ROW LEVEL SECURITY;

CREATE POLICY homepage_statistics_public_read
ON public.homepage_statistics
FOR SELECT
TO anon, authenticated
USING (TRUE);

REVOKE ALL ON TABLE public.homepage_statistics FROM anon, authenticated;
GRANT SELECT ON TABLE public.homepage_statistics TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.homepage_statistics TO service_role;
