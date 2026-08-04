CREATE TABLE public.city_page_read_models (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  publication_version_id UUID        NOT NULL REFERENCES public.publication_versions (id) ON DELETE CASCADE,
  city_id                UUID        NOT NULL REFERENCES public.cities (id),
  locale                 TEXT        NOT NULL,
  canonical_slug         TEXT        NOT NULL,
  payload                JSONB       NOT NULL,
  generated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT city_page_read_models_identity_key
  UNIQUE (publication_version_id, city_id, locale),

  CONSTRAINT city_page_read_models_slug_key
  UNIQUE (publication_version_id, canonical_slug, locale),

  CONSTRAINT city_page_read_models_payload_check
  CHECK (jsonb_typeof(payload) = 'object')
);

CREATE INDEX city_page_read_models_lookup_idx
ON public.city_page_read_models USING btree (canonical_slug, locale, publication_version_id);

ALTER TABLE public.city_page_read_models ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.city_page_read_models FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.city_page_read_models TO service_role;
