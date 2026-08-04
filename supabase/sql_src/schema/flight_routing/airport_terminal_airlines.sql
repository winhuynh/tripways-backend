-- Table: public.airport_terminal_airlines
-- Feature: Airport Knowledge
-- Purpose: Associate airlines with terminals for a bounded validity window.

CREATE TABLE public.airport_terminal_airlines (
  terminal_id       UUID         NOT NULL REFERENCES public.airport_terminals (id) ON DELETE CASCADE,
  airline_id        UUID         NOT NULL REFERENCES public.airlines (id),
  valid_from        DATE         NULL,
  valid_to          DATE         NULL,
  source_id         UUID         NOT NULL REFERENCES admin.data_sources (id),
  last_verified_at  TIMESTAMPTZ  NOT NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

  PRIMARY KEY (terminal_id, airline_id),
  CONSTRAINT airport_terminal_airlines_validity_check CHECK ((valid_from IS NULL) = (valid_to IS NULL)),
  CONSTRAINT airport_terminal_airlines_order_check CHECK (valid_from IS NULL OR valid_from <= valid_to)
);

ALTER TABLE public.airport_terminal_airlines ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.airport_terminal_airlines FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.airport_terminal_airlines TO service_role;

