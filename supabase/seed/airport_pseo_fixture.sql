-- Development-only fixture for the BKK airport pSEO preview.
-- Route and content sources are not production eligible, so refresh always keeps this page noindex.

INSERT INTO public.flight_routes (
  id,
  origin_airport_id,
  destination_airport_id,
  operating_airline_id,
  marketing_airline_id,
  status,
  frequency_per_week,
  days_of_week,
  seasonality,
  confidence_score,
  source_id,
  source_record_id,
  last_verified_at
)
VALUES (
  '60000000-0000-4000-8000-000000000099',
  '40000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000006',
  '50000000-0000-4000-8000-000000000002',
  '50000000-0000-4000-8000-000000000002',
  'verified_active',
  7,
  ARRAY[1, 2, 3, 4, 5, 6, 7]::SMALLINT[],
  'year_round',
  0.920,
  '10000000-0000-4000-8000-000000000001',
  'route-sin-dmk-airport-preview',
  '2026-07-27T00:00:00Z'
);

INSERT INTO public.flight_services (
  id,
  flight_route_id,
  operating_airline_id,
  marketing_airline_id,
  flight_number,
  valid_from,
  valid_to,
  days_of_week,
  departure_local_time,
  arrival_local_time,
  arrival_day_offset,
  duration_minutes,
  aircraft_type,
  confidence_score,
  source_id,
  source_record_id,
  last_verified_at
)
VALUES (
  '70000000-0000-4000-8000-000000000099',
  '60000000-0000-4000-8000-000000000099',
  '50000000-0000-4000-8000-000000000002',
  '50000000-0000-4000-8000-000000000002',
  'SQ708',
  '2026-01-01',
  '2026-12-31',
  ARRAY[1, 2, 3, 4, 5, 6, 7]::SMALLINT[],
  '10:00',
  '11:25',
  0,
  145,
  'A320',
  0.920,
  '10000000-0000-4000-8000-000000000001',
  'service-sin-dmk-airport-preview',
  '2026-07-27T00:00:00Z'
);

INSERT INTO public.pseo_pages (
  id,
  page_type,
  entity_key,
  locale,
  canonical_path,
  display_title,
  status,
  is_indexable,
  noindex_reason,
  content_updated_at
)
VALUES
  (
    '81100000-0000-4000-8000-000000000001',
    'airport',
    'bkk',
    'en-GB',
    '/airports/suvarnabhumi-bkk',
    'Suvarnabhumi Airport arrival, departure and transport guide',
    'review',
    FALSE,
    'development_fixture',
    '2026-07-27T00:00:00Z'
  ),
  (
    '81100000-0000-4000-8000-000000000002',
    'airport',
    'dmk',
    'en-GB',
    '/airports/don-mueang-dmk',
    'Don Mueang Airport arrival, departure and transport guide',
    'review',
    FALSE,
    'development_fixture',
    '2026-07-27T00:00:00Z'
  ),
  (
    '81100000-0000-4000-8000-000000000003',
    'airport',
    'sin',
    'en-GB',
    '/airports/singapore-changi-sin',
    'Singapore Changi Airport arrival, departure and transport guide',
    'review',
    FALSE,
    'development_fixture',
    '2026-07-27T00:00:00Z'
  );

INSERT INTO public.airport_pages (
  id,
  pseo_page_id,
  airport_id,
  locale,
  h1,
  subheadline,
  seo_title,
  meta_description,
  og_title,
  og_description,
  intro,
  orientation_summary,
  arrival_summary,
  departure_summary,
  primary_city_area_label,
  city_distance_km,
  content_reviewed_at
)
VALUES
  (
    '82100000-0000-4000-8000-000000000001',
    '81100000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000003',
    'en-GB',
    'Suvarnabhumi Airport (BKK) Guide',
    'Plan arrival, departure and travel between Suvarnabhumi Airport and Bangkok.',
    'Suvarnabhumi Airport (BKK) Guide: Arrivals, Departures & Transport | Tripways',
    'Plan arrival or departure at Suvarnabhumi Airport, compare estimated transport options and browse verified direct flights to and from BKK.',
    'Suvarnabhumi Airport arrival, departure and transport guide',
    'Plan the practical steps for using BKK and travelling between the airport and Bangkok.',
    'Suvarnabhumi Airport is Bangkok''s primary international airport and connects the city with destinations across Asia and Europe.',
    'BKK is east of central Bangkok. Check your terminal and whether the journey is domestic or international before travel.',
    'After landing, follow the signed arrival flow for baggage reclaim, immigration when applicable, customs and onward transport.',
    'Before departure, confirm the terminal, airline check-in guidance and any immigration or security requirements.',
    'Central Bangkok',
    30,
    '2026-07-27T00:00:00Z'
  ),
  (
    '82100000-0000-4000-8000-000000000002',
    '81100000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000006',
    'en-GB',
    'Don Mueang International Airport (DMK) Guide',
    'Plan arrival, departure and travel between Don Mueang Airport and Bangkok.',
    'Don Mueang Airport (DMK) Guide: Arrivals, Departures & Transport | Tripways',
    'Plan arrival or departure at Don Mueang Airport, compare estimated transport options and browse verified direct flights to and from DMK.',
    'Don Mueang Airport arrival, departure and transport guide',
    'Plan the practical steps for using DMK and travelling between the airport and Bangkok.',
    'Don Mueang International Airport is a major Bangkok base for low-cost and regional flights across Thailand and Southeast Asia.',
    'DMK is north of central Bangkok and is distinct from BKK. Confirm the airport code before arranging transport.',
    'After landing, follow signs for baggage reclaim, immigration when applicable, customs and the public arrival area.',
    'Before departure, confirm the terminal and allow time for check-in, security and immigration when applicable.',
    'Central Bangkok',
    24,
    '2026-07-27T00:00:00Z'
  ),
  (
    '82100000-0000-4000-8000-000000000003',
    '81100000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000002',
    'en-GB',
    'Singapore Changi Airport (SIN) Guide',
    'Plan arrival, departure and travel between Singapore Changi Airport and central Singapore.',
    'Singapore Changi Airport (SIN) Guide: Arrivals, Departures & Transport | Tripways',
    'Plan arrival or departure at Singapore Changi Airport, compare estimated transport options and browse verified direct flights to and from SIN.',
    'Singapore Changi Airport arrival, departure and transport guide',
    'Plan the practical steps for using SIN and travelling between the airport and central Singapore.',
    'Singapore Changi Airport is the city-state''s principal international gateway and a major connection hub for Asia and long-haul travel.',
    'SIN is east of central Singapore. Terminal and immigration steps vary by flight, so verify them before travel.',
    'After landing, follow the applicable immigration, baggage reclaim and customs flow before choosing onward transport.',
    'Before departure, confirm the terminal and airline guidance, then allow time for check-in, immigration and security.',
    'Central Singapore',
    20,
    '2026-07-27T00:00:00Z'
  );

INSERT INTO public.airport_journey_steps (
  airport_page_id,
  locale,
  journey_type,
  audience,
  title,
  body,
  display_order,
  primary_source_url,
  last_verified_at,
  status,
  data_version
)
SELECT
  page.id,
  page.locale,
  step.journey_type,
  step.audience,
  step.title,
  step.body,
  step.display_order,
  step.primary_source_url,
  '2026-07-27T00:00:00Z',
  'published',
  '00000000-0000-4000-8000-000000000001'
FROM public.airport_pages page
CROSS JOIN (
  VALUES
    ('arrival', 'all', 'Follow the arrival signs', 'Follow the signed route for baggage reclaim and the public arrivals area.', 1, 'https://example.com/development-only/airport-arrivals'),
    ('arrival', 'all', 'Collect checked baggage', 'Check the carousel display and report missing or damaged baggage to the operating airline before leaving the reclaim area.', 2, 'https://example.com/development-only/airport-arrivals'),
    ('arrival', 'all', 'Enter the arrivals hall', 'Use the signed exit after baggage and any applicable border formalities to reach the public arrivals hall.', 3, 'https://example.com/development-only/airport-arrivals'),
    ('arrival', 'all', 'Find the meeting point', 'Confirm the level, door or named meeting point before meeting a driver or another traveller.', 4, 'https://example.com/development-only/airport-arrivals'),
    ('arrival', 'all', 'Choose onward transport', 'Compare rail, taxi and pre-booked transfer pickup instructions before leaving the terminal.', 5, 'https://example.com/development-only/airport-arrivals'),
    ('arrival', 'international', 'Complete border formalities', 'Follow the official immigration and customs process that applies to your journey.', 2, 'https://example.com/development-only/airport-arrivals'),
    ('departure', 'all', 'Confirm terminal and check-in', 'Check the airline terminal and check-in guidance before travelling to the airport.', 1, 'https://example.com/development-only/airport-departures'),
    ('departure', 'all', 'Travel to the airport', 'Choose a transport option that allows for variable Bangkok traffic or the operating window of public transport.', 2, 'https://example.com/development-only/airport-departures'),
    ('departure', 'all', 'Use the correct drop-off', 'Follow signs for the airline check-in area, departure level or the applicable parking facility.', 3, 'https://example.com/development-only/airport-departures'),
    ('departure', 'all', 'Check in and drop bags', 'Follow the operating airline deadline and keep required travel documents available.', 4, 'https://example.com/development-only/airport-departures'),
    ('departure', 'all', 'Complete security', 'Allow sufficient time for screening and follow current restrictions for cabin baggage and liquids.', 5, 'https://example.com/development-only/airport-departures'),
    ('departure', 'all', 'Continue to the gate', 'Check the gate and allow time to travel through the terminal or satellite concourse.', 6, 'https://example.com/development-only/airport-departures'),
    ('departure', 'international', 'Allow time for formalities', 'Allow time for check-in, immigration and security requirements that apply to the flight.', 2, 'https://example.com/development-only/airport-departures')
) AS step(journey_type, audience, title, body, display_order, primary_source_url)
WHERE page.id IN (
  '82100000-0000-4000-8000-000000000001',
  '82100000-0000-4000-8000-000000000002',
  '82100000-0000-4000-8000-000000000003'
);

INSERT INTO public.airport_access_options (
  airport_page_id,
  journey_direction,
  access_type,
  name,
  destination_label,
  summary,
  duration_min_minutes,
  duration_max_minutes,
  price_min,
  price_max,
  currency_code,
  operating_hours_summary,
  pickup_location_summary,
  best_for_label,
  luggage_summary,
  accessibility_summary,
  primary_source_url,
  last_verified_at,
  display_order,
  status
)
VALUES
  (
    '82100000-0000-4000-8000-000000000001',
    'from_airport',
    'rail',
    'Airport Rail Link',
    'Phaya Thai',
    'Rail connects BKK with central Bangkok interchange stations without road traffic.',
    25,
    35,
    15,
    45,
    'THB',
    'Service hours vary; verify before travel.',
    'Basement level at Suvarnabhumi Airport',
    'Predictable journey time',
    'Space is available for standard luggage.',
    'Step-free routes are available; confirm lift access before travel.',
    'https://example.com/development-only/bkk-rail',
    '2026-07-27T00:00:00Z',
    1,
    'published'
  ),
  (
    '82100000-0000-4000-8000-000000000001',
    'from_airport',
    'taxi',
    'Public taxi',
    'Central Bangkok',
    'Metered taxis provide a direct journey from the airport to the city.',
    45,
    90,
    350,
    500,
    'THB',
    'Available 24 hours.',
    'Official taxi queue on Level 1',
    'Groups and heavy luggage',
    'Vehicle luggage capacity varies.',
    NULL,
    'https://example.com/development-only/bkk-taxi',
    '2026-07-27T00:00:00Z',
    2,
    'published'
  ),
  (
    '82100000-0000-4000-8000-000000000001',
    'to_airport',
    'rail',
    'Airport Rail Link',
    'Suvarnabhumi Airport',
    'Rail runs from central Bangkok interchange stations to the BKK terminal.',
    25,
    35,
    15,
    45,
    'THB',
    'Service hours vary; verify before travel.',
    'Phaya Thai or Makkasan station',
    'Predictable journey time',
    'Space is available for standard luggage.',
    'Step-free routes are available; confirm lift access before travel.',
    'https://example.com/development-only/bkk-rail',
    '2026-07-27T00:00:00Z',
    3,
    'published'
  ),
  (
    '82100000-0000-4000-8000-000000000001',
    'to_airport',
    'taxi',
    'Public taxi',
    'Suvarnabhumi Airport departures',
    'A taxi provides a direct journey from Bangkok to the departure level.',
    45,
    90,
    350,
    500,
    'THB',
    'Available 24 hours.',
    'Hotel or street pickup in Bangkok',
    'Groups and heavy luggage',
    'Vehicle luggage capacity varies.',
    NULL,
    'https://example.com/development-only/bkk-taxi',
    '2026-07-27T00:00:00Z',
    4,
    'published'
  );

INSERT INTO public.airport_parking_information (
  airport_page_id,
  summary,
  short_stay_available,
  long_stay_available,
  reservation_available,
  shuttle_available,
  primary_source_url,
  last_verified_at,
  status
)
VALUES (
  '82100000-0000-4000-8000-000000000001',
  'The airport provides short-stay and long-stay parking options.',
  TRUE,
  TRUE,
  NULL,
  TRUE,
  'https://example.com/development-only/bkk-parking',
  '2026-07-27T00:00:00Z',
  'published'
);

INSERT INTO public.airport_lounges (
  airport_page_id,
  name,
  location_summary,
  location_type,
  access_summary,
  operating_hours_summary,
  amenities,
  estimated_price_min,
  estimated_price_max,
  currency_code,
  affiliate_url,
  primary_source_url,
  last_verified_at,
  display_order,
  status
)
VALUES (
  '82100000-0000-4000-8000-000000000001',
  'BKK International Lounge Preview',
  'International departures area',
  'airside',
  'Access depends on airline eligibility, membership or an eligible paid programme.',
  'Open 24 hours; individual locations may vary.',
  ARRAY['wifi', 'food', 'showers']::TEXT[],
  1200,
  1500,
  'THB',
  'https://example.com/development-only/bkk-lounge-booking',
  'https://example.com/development-only/bkk-lounge',
  '2026-07-27T00:00:00Z',
  1,
  'published'
);

INSERT INTO public.airport_page_notices (
  airport_page_id,
  notice_type,
  title,
  body,
  severity,
  primary_source_url,
  last_verified_at,
  display_order,
  status
)
VALUES (
  '82100000-0000-4000-8000-000000000001',
  'airport_confusion',
  'Check whether your Bangkok flight uses BKK or DMK',
  'Bangkok has two major airports. Confirm the IATA code before arranging ground transport.',
  'important',
  'https://example.com/development-only/bangkok-airports',
  '2026-07-27T00:00:00Z',
  1,
  'published'
);

INSERT INTO public.airport_page_faqs (
  airport_page_id,
  question,
  answer,
  answer_type,
  display_order,
  status,
  reviewed_at
)
VALUES (
  '82100000-0000-4000-8000-000000000001',
  'Where can I fly directly from BKK?',
  'Use the direct-route explorer to see destinations supported by the current reviewed route dataset.',
  'data_backed',
  1,
  'published',
  '2026-07-27T00:00:00Z'
);

INSERT INTO public.airport_access_options (
  airport_page_id,
  journey_direction,
  access_type,
  name,
  destination_label,
  summary,
  duration_min_minutes,
  duration_max_minutes,
  operating_hours_summary,
  primary_source_url,
  last_verified_at,
  display_order,
  status
)
VALUES
  (
    '82100000-0000-4000-8000-000000000002',
    'both',
    'bus',
    'Bangkok public bus',
    'Central Bangkok',
    'Public bus routes connect Don Mueang Airport with several Bangkok transport interchanges.',
    35,
    70,
    'Service frequency varies by route and time of day.',
    'https://example.com/development-only/dmk-access',
    '2026-07-27T00:00:00Z',
    1,
    'published'
  ),
  (
    '82100000-0000-4000-8000-000000000003',
    'both',
    'metro',
    'MRT connection',
    'Central Singapore',
    'Metro services connect Changi Airport with central Singapore through the wider MRT network.',
    35,
    50,
    'Operating hours vary; verify the first and last train before travel.',
    'https://example.com/development-only/sin-access',
    '2026-07-27T00:00:00Z',
    1,
    'published'
  );

INSERT INTO public.airport_parking_information (
  airport_page_id,
  summary,
  short_stay_available,
  long_stay_available,
  reservation_available,
  shuttle_available,
  primary_source_url,
  last_verified_at,
  status
)
VALUES
  (
    '82100000-0000-4000-8000-000000000002',
    'Don Mueang Airport provides short-stay and longer-stay parking options.',
    TRUE,
    TRUE,
    NULL,
    NULL,
    'https://example.com/development-only/dmk-parking',
    '2026-07-27T00:00:00Z',
    'published'
  ),
  (
    '82100000-0000-4000-8000-000000000003',
    'Changi Airport provides parking options for short visits and longer trips.',
    TRUE,
    TRUE,
    NULL,
    NULL,
    'https://example.com/development-only/sin-parking',
    '2026-07-27T00:00:00Z',
    'published'
  );

INSERT INTO public.airport_lounges (
  airport_page_id,
  name,
  location_summary,
  location_type,
  access_summary,
  operating_hours_summary,
  amenities,
  estimated_price_min,
  estimated_price_max,
  currency_code,
  affiliate_url,
  primary_source_url,
  last_verified_at,
  display_order,
  status
)
VALUES
  (
    '82100000-0000-4000-8000-000000000002',
    'DMK Departure Lounge Preview',
    'International departures area',
    'airside',
    'Access depends on airline eligibility, membership or an eligible paid programme.',
    NULL,
    ARRAY['wifi', 'food', 'work_area']::TEXT[],
    NULL,
    NULL,
    NULL,
    NULL,
    'https://example.com/development-only/dmk-lounge',
    '2026-07-27T00:00:00Z',
    1,
    'published'
  ),
  (
    '82100000-0000-4000-8000-000000000003',
    'SIN International Lounge Preview',
    'International departures area',
    'airside',
    'Access depends on airline eligibility, membership or an eligible paid programme.',
    NULL,
    ARRAY['wifi', 'food', 'showers', 'rest_area']::TEXT[],
    NULL,
    NULL,
    NULL,
    NULL,
    'https://example.com/development-only/sin-lounge',
    '2026-07-27T00:00:00Z',
    1,
    'published'
  ),
  (
    '82100000-0000-4000-8000-000000000003',
    'SIN Transit Lounge Preview',
    'Transit area',
    'airside',
    'Access varies by programme and may be available as a paid visit.',
    NULL,
    ARRAY['wifi', 'drinks', 'work_area']::TEXT[],
    NULL,
    NULL,
    NULL,
    NULL,
    'https://example.com/development-only/sin-transit-lounge',
    '2026-07-27T00:00:00Z',
    2,
    'published'
  );

INSERT INTO public.airport_page_notices (
  airport_page_id,
  notice_type,
  title,
  body,
  severity,
  primary_source_url,
  last_verified_at,
  display_order,
  status
)
VALUES
  (
    '82100000-0000-4000-8000-000000000002',
    'airport_confusion',
    'Check whether your Bangkok flight uses DMK or BKK',
    'Bangkok has two major airports. Confirm the IATA code before arranging ground transport.',
    'important',
    'https://example.com/development-only/bangkok-airports',
    '2026-07-27T00:00:00Z',
    1,
    'published'
  ),
  (
    '82100000-0000-4000-8000-000000000003',
    'connection',
    'Leave enough time for a connection',
    'Connection requirements depend on airlines, tickets and immigration rules. Confirm the applicable process before travel.',
    'important',
    'https://example.com/development-only/sin-connections',
    '2026-07-27T00:00:00Z',
    1,
    'published'
  );

INSERT INTO public.airport_page_faqs (
  airport_page_id,
  question,
  answer,
  answer_type,
  display_order,
  status,
  reviewed_at
)
VALUES
  (
    '82100000-0000-4000-8000-000000000002',
    'Where can I fly directly from DMK?',
    'Use the direct-route explorer to see destinations supported by the current reviewed route dataset.',
    'data_backed',
    1,
    'published',
    '2026-07-27T00:00:00Z'
  ),
  (
    '82100000-0000-4000-8000-000000000003',
    'Where can I fly directly from SIN?',
    'Use the direct-route explorer to see destinations supported by the current reviewed route dataset.',
    'data_backed',
    1,
    'published',
    '2026-07-27T00:00:00Z'
  );
