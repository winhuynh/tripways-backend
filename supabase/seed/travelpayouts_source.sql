-- Travelpayouts/Aviasales short-lived content-observation source.
INSERT INTO admin.data_sources (
  id,
  code,
  name
)
VALUES (
  '11000000-0000-4000-8000-000000000002',
  'travelpayouts',
  'Travelpayouts / Aviasales Data API'
)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  updated_at = now();

