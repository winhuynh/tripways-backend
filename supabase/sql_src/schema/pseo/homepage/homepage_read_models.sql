CREATE TABLE public.homepage_read_models (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  publication_version_id UUID        NOT NULL REFERENCES public.publication_versions (id) ON DELETE CASCADE,
  locale                 TEXT        NOT NULL,
  payload                JSONB       NOT NULL,
  generated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT homepage_read_models_identity_key
  UNIQUE (publication_version_id, locale),

  CONSTRAINT homepage_read_models_locale_check
  CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),

  CONSTRAINT homepage_read_models_payload_check
  CHECK (jsonb_typeof(payload) = 'object')
);

CREATE INDEX homepage_read_models_lookup_idx
ON public.homepage_read_models USING btree (locale, publication_version_id);

ALTER TABLE public.homepage_read_models ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.homepage_read_models FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.homepage_read_models TO service_role;
