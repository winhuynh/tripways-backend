CREATE TABLE public.route_page_read_models (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  publication_version_id UUID        NOT NULL REFERENCES public.publication_versions (id) ON DELETE CASCADE,
  route_page_id          UUID        NOT NULL REFERENCES public.route_pages (id),
  locale                 TEXT        NOT NULL,
  canonical_slug         TEXT        NOT NULL,
  payload                JSONB       NOT NULL,
  metadata               JSONB       NOT NULL,
  generated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT route_page_read_models_identity_key
  UNIQUE (publication_version_id, route_page_id, locale),

  CONSTRAINT route_page_read_models_slug_key
  UNIQUE (publication_version_id, canonical_slug, locale),

  CONSTRAINT route_page_read_models_payload_check
  CHECK (jsonb_typeof(payload) = 'object'),

  CONSTRAINT route_page_read_models_metadata_check
  CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX route_page_read_models_lookup_idx
ON public.route_page_read_models USING btree (canonical_slug, locale, publication_version_id);

ALTER TABLE public.route_page_read_models ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.route_page_read_models FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_page_read_models TO service_role;
