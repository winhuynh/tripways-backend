-- Table: public.publication_versions
-- Feature: Shared Read Models
-- Purpose: Track atomic candidate and current read-model publications.

CREATE TABLE public.publication_versions (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  status         TEXT         NOT NULL DEFAULT 'building',
  is_current     BOOLEAN      NOT NULL DEFAULT FALSE,
  source_type    TEXT         NOT NULL,
  started_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
  published_at   TIMESTAMPTZ  NULL,
  failure_code   TEXT         NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT publication_versions_status_check
    CHECK (status IN ('building', 'published', 'failed', 'retired')),

  CONSTRAINT publication_versions_source_check
    CHECK (source_type IN ('production', 'development_fixture')),

  CONSTRAINT publication_versions_current_check
    CHECK (is_current = FALSE OR (status = 'published' AND published_at IS NOT NULL)),

  CONSTRAINT publication_versions_failure_check
    CHECK ((status = 'failed') = (failure_code IS NOT NULL))
);

CREATE UNIQUE INDEX publication_versions_one_current_idx
ON public.publication_versions USING btree (is_current)
WHERE is_current = TRUE;

ALTER TABLE public.publication_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.publication_versions FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.publication_versions TO service_role;
