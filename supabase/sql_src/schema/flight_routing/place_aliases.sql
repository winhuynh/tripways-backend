-- Table: public.place_aliases
-- Feature: Place Discovery
-- Purpose: Provide localized provider-neutral search aliases for cities, airports, and metro areas.

CREATE TABLE public.place_aliases (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type       TEXT         NOT NULL,
  entity_id         UUID         NOT NULL,
  locale            TEXT         NOT NULL,
  alias             TEXT         NOT NULL,
  normalized_alias  TEXT         NOT NULL,
  alias_type        TEXT         NOT NULL DEFAULT 'name',
  source_id         UUID         NOT NULL REFERENCES admin.data_sources (id),
  source_record_id  TEXT         NOT NULL,
  last_verified_at  TIMESTAMPTZ  NOT NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT place_aliases_source_record_key UNIQUE (source_id, source_record_id),
  CONSTRAINT place_aliases_identity_key UNIQUE (entity_type, entity_id, locale, normalized_alias),
  CONSTRAINT place_aliases_entity_type_check CHECK (entity_type IN ('city', 'airport', 'metro_area')),
  CONSTRAINT place_aliases_alias_type_check CHECK (alias_type IN ('name', 'code', 'historic', 'local')),
  CONSTRAINT place_aliases_locale_check CHECK (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$')
);

CREATE INDEX place_aliases_lookup_idx ON public.place_aliases USING btree (locale, normalized_alias);
ALTER TABLE public.place_aliases ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.place_aliases FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.place_aliases TO service_role;

