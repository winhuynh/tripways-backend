-- Table: public.pseo_internal_links
-- Feature: Interactive pSEO
-- Purpose: Store a precomputed semantic internal-link graph.
-- Responsibilities: Keep anchor, placement, relevance, and data-version decisions deterministic.

CREATE TABLE public.pseo_internal_links (
  id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  source_page_id    UUID            NOT NULL REFERENCES public.pseo_pages (id) ON DELETE CASCADE,
  target_page_id    UUID            NOT NULL REFERENCES public.pseo_pages (id) ON DELETE CASCADE,
  link_cluster      TEXT            NOT NULL,
  anchor_text       TEXT            NOT NULL,
  secondary_text    TEXT            NULL,
  display_zone      TEXT            NOT NULL,
  relevance_score   NUMERIC(8, 4)   NOT NULL,
  display_order     SMALLINT        NOT NULL,
  is_featured       BOOLEAN         NOT NULL DEFAULT FALSE,
  data_version      UUID            NULL,
  generated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

  CONSTRAINT pseo_internal_links_target_key
    UNIQUE (source_page_id, target_page_id, link_cluster),

  CONSTRAINT pseo_internal_links_direction_check
    CHECK (source_page_id <> target_page_id),

  CONSTRAINT pseo_internal_links_cluster_check
    CHECK (
      link_cluster IN (
        'popular_routes',
        'airports',
        'airlines',
        'direct_countries',
        'change_source_city',
        'reverse_routes',
        'guides',
        'outbound_routes',
        'inbound_routes',
        'nearby_airports',
        'city_flights_from',
        'city_flights_to',
        'airport_airlines'
      )
    ),

  CONSTRAINT pseo_internal_links_anchor_check
    CHECK (
      anchor_text = btrim(anchor_text)
      AND char_length(anchor_text) BETWEEN 1 AND 180
    ),

  CONSTRAINT pseo_internal_links_zone_check
    CHECK (display_zone ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'),

  CONSTRAINT pseo_internal_links_score_check
    CHECK (relevance_score >= 0),

  CONSTRAINT pseo_internal_links_order_check
    CHECK (display_order > 0)
);

CREATE INDEX pseo_internal_links_source_cluster_order_idx
ON public.pseo_internal_links USING btree (
  source_page_id,
  link_cluster,
  display_order,
  relevance_score DESC
);

ALTER TABLE public.pseo_internal_links ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.pseo_internal_links FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.pseo_internal_links TO service_role;
