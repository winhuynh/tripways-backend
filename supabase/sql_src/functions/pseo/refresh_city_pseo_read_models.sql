-- ============================================================================
-- Function: public.refresh_city_pseo_read_models
-- Feature: Interactive pSEO
-- Purpose: Preserve the previous refresh contract during the airport-page rollout.
-- Responsibilities: Delegate directly to the single shared pSEO refresh function.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.refresh_city_pseo_read_models()
RETURNS JSONB
LANGUAGE sql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT public.refresh_pseo_read_models();
$$;

REVOKE ALL ON FUNCTION public.refresh_city_pseo_read_models()
FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_city_pseo_read_models() TO service_role;
