-- Production-capable OurAirports source configuration for local parity and deployment seeding.

INSERT INTO admin.data_sources (
  id,
  code,
  provider_code,
  name,
  source_type,
  environment_scope,
  production_allowed,
  seo_allowed,
  derived_data_allowed,
  storage_allowed,
  retention_days,
  production_display_allowed,
  cache_allowed,
  max_cache_ttl_seconds,
  attribution_text,
  attribution_url,
  license_notes
)
VALUES (
  '11000000-0000-4000-8000-000000000001',
  'ourairports',
  'ourairports',
  'OurAirports',
  'base_data',
  'production',
  TRUE,
  TRUE,
  TRUE,
  TRUE,
  30,
  TRUE,
  TRUE,
  86400,
  'OurAirports public-domain airport data',
  'https://ourairports.com',
  'Public-domain data; retain source checksum, timestamp, filter version, and attribution.'
)
ON CONFLICT (code)
DO UPDATE SET
  provider_code = EXCLUDED.provider_code,
  name = EXCLUDED.name,
  source_type = EXCLUDED.source_type,
  environment_scope = EXCLUDED.environment_scope,
  production_allowed = EXCLUDED.production_allowed,
  seo_allowed = EXCLUDED.seo_allowed,
  derived_data_allowed = EXCLUDED.derived_data_allowed,
  storage_allowed = EXCLUDED.storage_allowed,
  retention_days = EXCLUDED.retention_days,
  production_display_allowed = EXCLUDED.production_display_allowed,
  cache_allowed = EXCLUDED.cache_allowed,
  max_cache_ttl_seconds = EXCLUDED.max_cache_ttl_seconds,
  attribution_text = EXCLUDED.attribution_text,
  attribution_url = EXCLUDED.attribution_url,
  license_notes = EXCLUDED.license_notes,
  updated_at = now();
