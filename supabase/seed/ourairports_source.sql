-- Production-capable OurAirports source configuration for local parity and deployment seeding.
INSERT INTO admin.data_sources (
  id,
  code,
  name,
  is_fixture,
  is_approved,
  environment
)
VALUES (
  '11000000-0000-4000-8000-000000000001',
  'ourairports',
  'OurAirports',
  false,
  true,
  'all'
)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  is_fixture = EXCLUDED.is_fixture,
  is_approved = EXCLUDED.is_approved,
  environment = EXCLUDED.environment,
  updated_at = now();

