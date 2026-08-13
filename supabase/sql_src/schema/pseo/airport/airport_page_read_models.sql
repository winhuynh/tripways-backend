CREATE TABLE public.airport_page_read_models (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  publication_version_id UUID        NOT NULL REFERENCES public.publication_versions (id) ON DELETE CASCADE,
  airport_id             UUID        NOT NULL REFERENCES public.airports (id),
  locale                 TEXT        NOT NULL,
  airport_iata           TEXT        NOT NULL,
  payload                JSONB       NOT NULL,
  metadata               JSONB       NOT NULL,
  generated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT airport_page_read_models_identity_key
  UNIQUE (publication_version_id, airport_id, locale),

  CONSTRAINT airport_page_read_models_iata_key
  UNIQUE (publication_version_id, airport_iata, locale),

  CONSTRAINT airport_page_read_models_iata_check
  CHECK (airport_iata ~ '^[A-Z0-9]{3}$'),

  CONSTRAINT airport_page_read_models_payload_check
  CHECK (jsonb_typeof(payload) = 'object'),

  CONSTRAINT airport_page_read_models_metadata_check
  CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX airport_page_read_models_lookup_idx
ON public.airport_page_read_models USING btree (airport_iata, locale, publication_version_id);

ALTER TABLE public.airport_page_read_models ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.airport_page_read_models FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_page_read_models TO service_role;
