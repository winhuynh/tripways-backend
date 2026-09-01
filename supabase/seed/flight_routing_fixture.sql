-- Minimal provider-neutral fixture for local route and pSEO testing.
INSERT INTO admin.data_sources (id,code,name)
VALUES ('10000000-0000-4000-8000-000000000001','route_discovery_fixture','Route Discovery Development Fixture');

INSERT INTO public.countries (id,iso2,iso3,name,slug,region,subregion,source_id,source_record_id) VALUES
('20000000-0000-4000-8000-000000000001','VN','VNM','Vietnam','vietnam','Asia','South-Eastern Asia','10000000-0000-4000-8000-000000000001','country-vn'),
('20000000-0000-4000-8000-000000000002','SG','SGP','Singapore','singapore','Asia','South-Eastern Asia','10000000-0000-4000-8000-000000000001','country-sg'),
('20000000-0000-4000-8000-000000000003','TH','THA','Thailand','thailand','Asia','South-Eastern Asia','10000000-0000-4000-8000-000000000001','country-th'),
('20000000-0000-4000-8000-000000000004','GB','GBR','United Kingdom','united-kingdom','Europe','Northern Europe','10000000-0000-4000-8000-000000000001','country-gb'),
('20000000-0000-4000-8000-000000000005','JP','JPN','Japan','japan','Asia','Eastern Asia','10000000-0000-4000-8000-000000000001','country-jp');

INSERT INTO public.cities (id,country_id,name,slug,iata_code,currency_code,primary_language,latitude,longitude,timezone,source_id,source_record_id) VALUES
('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Ho Chi Minh City','ho-chi-minh-city','SGN','VND','vi',10.8231,106.6297,'Asia/Ho_Chi_Minh','10000000-0000-4000-8000-000000000001','city-sgn'),
('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','Singapore','singapore','SIN','SGD','en',1.3521,103.8198,'Asia/Singapore','10000000-0000-4000-8000-000000000001','city-sin'),
('30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000003','Bangkok','bangkok','BKK','THB','th',13.7563,100.5018,'Asia/Bangkok','10000000-0000-4000-8000-000000000001','city-bkk'),
('30000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000004','London','london','LON','GBP','en',51.5072,-0.1276,'Europe/London','10000000-0000-4000-8000-000000000001','city-lon'),
('30000000-0000-4000-8000-000000000005','20000000-0000-4000-8000-000000000005','Tokyo','tokyo','TYO','JPY','ja',35.6762,139.6503,'Asia/Tokyo','10000000-0000-4000-8000-000000000001','city-tyo'),
('30000000-0000-4000-8000-000000000006','20000000-0000-4000-8000-000000000001','Hanoi','hanoi','HAN','VND','vi',21.0278,105.8342,'Asia/Ho_Chi_Minh','10000000-0000-4000-8000-000000000001','city-han');

INSERT INTO public.airports (id,iata,icao,name,slug,city_id,country_id,latitude,longitude,timezone,airport_type,status,is_hub,min_transit_minutes,source_id,source_record_id) VALUES
('40000000-0000-4000-8000-000000000001','SGN','VVTS','Tan Son Nhat International Airport','tan-son-nhat-international-airport','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',10.8188,106.6520,'Asia/Ho_Chi_Minh','large_airport','active',FALSE,90,'10000000-0000-4000-8000-000000000001','airport-sgn'),
('40000000-0000-4000-8000-000000000002','SIN','WSSS','Singapore Changi Airport','singapore-changi-airport','30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002',1.3644,103.9915,'Asia/Singapore','large_airport','active',TRUE,60,'10000000-0000-4000-8000-000000000001','airport-sin'),
('40000000-0000-4000-8000-000000000003','BKK','VTBS','Suvarnabhumi Airport','suvarnabhumi-airport','30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000003',13.6900,100.7501,'Asia/Bangkok','large_airport','active',FALSE,75,'10000000-0000-4000-8000-000000000001','airport-bkk'),
('40000000-0000-4000-8000-000000000004','LHR','EGLL','Heathrow Airport','heathrow-airport','30000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000004',51.4700,-0.4543,'Europe/London','large_airport','active',FALSE,120,'10000000-0000-4000-8000-000000000001','airport-lhr'),
('40000000-0000-4000-8000-000000000005','HND','RJTT','Haneda Airport','haneda-airport','30000000-0000-4000-8000-000000000005','20000000-0000-4000-8000-000000000005',35.5494,139.7798,'Asia/Tokyo','large_airport','active',FALSE,75,'10000000-0000-4000-8000-000000000001','airport-hnd'),
('40000000-0000-4000-8000-000000000006','HAN','VVNB','Noi Bai International Airport','noi-bai-international-airport','30000000-0000-4000-8000-000000000006','20000000-0000-4000-8000-000000000001',21.2187,105.8042,'Asia/Ho_Chi_Minh','large_airport','active',FALSE,75,'10000000-0000-4000-8000-000000000001','airport-han'),
('40000000-0000-4000-8000-000000000007','DMK','VTBD','Don Mueang International Airport','don-mueang-international-airport','30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000003',13.9126,100.6068,'Asia/Bangkok','large_airport','active',FALSE,60,'10000000-0000-4000-8000-000000000001','airport-dmk'),
('40000000-0000-4000-8000-000000000008','LGW','EGKK','Gatwick Airport','gatwick-airport','30000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000004',51.1537,-0.1821,'Europe/London','large_airport','active',FALSE,90,'10000000-0000-4000-8000-000000000001','airport-lgw'),
('40000000-0000-4000-8000-000000000009','NRT','RJAA','Narita International Airport','narita-international-airport','30000000-0000-4000-8000-000000000005','20000000-0000-4000-8000-000000000005',35.7720,140.3929,'Asia/Tokyo','large_airport','active',FALSE,90,'10000000-0000-4000-8000-000000000001','airport-nrt');

INSERT INTO public.airlines (id,iata,icao,name,slug,country_id,business_model,status,source_id,source_record_id) VALUES
('50000000-0000-4000-8000-000000000001','VN','HVN','Vietnam Airlines','vietnam-airlines','20000000-0000-4000-8000-000000000001','full_service','active','10000000-0000-4000-8000-000000000001','airline-vn'),
('50000000-0000-4000-8000-000000000002','SQ','SIA','Singapore Airlines','singapore-airlines','20000000-0000-4000-8000-000000000002','full_service','active','10000000-0000-4000-8000-000000000001','airline-sq'),
('50000000-0000-4000-8000-000000000003','TG','THA','Thai Airways','thai-airways','20000000-0000-4000-8000-000000000003','full_service','active','10000000-0000-4000-8000-000000000001','airline-tg'),
('50000000-0000-4000-8000-000000000004','VJ','VJC','VietJet Air','vietjet-air','20000000-0000-4000-8000-000000000001','low_cost','active','10000000-0000-4000-8000-000000000001','airline-vj'),
('50000000-0000-4000-8000-000000000005','BA','BAW','British Airways','british-airways','20000000-0000-4000-8000-000000000004','full_service','active','10000000-0000-4000-8000-000000000001','airline-ba'),
('50000000-0000-4000-8000-000000000006','JL','JAL','Japan Airlines','japan-airlines','20000000-0000-4000-8000-000000000005','full_service','active','10000000-0000-4000-8000-000000000001','airline-jl');

INSERT INTO public.direct_flight_routes (
  id, origin_airport_id, destination_airport_id, origin_iata, destination_iata,
  airline_iata, airline_name, airline_id, flight_numbers, flight_duration_minutes,
  distance_km, days_of_week, aircraft_types, source_id, source_record_id, is_active
) VALUES
('70000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000002', 'SGN', 'SIN', 'VN', 'Vietnam Airlines', '50000000-0000-4000-8000-000000000001', ARRAY['VN651'], 125, 1085, '{1,2,3,4,5,6,7}', ARRAY['A321'], '10000000-0000-4000-8000-000000000001', 'route-sgn-sin-vn', TRUE),
('70000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000002', 'SGN', 'SIN', 'SQ', 'Singapore Airlines', '50000000-0000-4000-8000-000000000002', ARRAY['SQ173'], 125, 1085, '{1,2,3,4,5,6,7}', ARRAY['B787'], '10000000-0000-4000-8000-000000000001', 'route-sgn-sin-sq', TRUE),
('70000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000004', 'SIN', 'LHR', 'SQ', 'Singapore Airlines', '50000000-0000-4000-8000-000000000002', ARRAY['SQ308'], 820, 10885, '{1,2,3,4,5,6,7}', ARRAY['A380'], '10000000-0000-4000-8000-000000000001', 'route-sin-lhr-sq', TRUE),
('70000000-0000-4000-8000-000000000004', '40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000004', 'SGN', 'LHR', 'VN', 'Vietnam Airlines', '50000000-0000-4000-8000-000000000001', ARRAY['VN51'], 780, 10200, '{2,4,6}', ARRAY['B787'], '10000000-0000-4000-8000-000000000001', 'route-sgn-lhr-vn', TRUE),
('70000000-0000-4000-8000-000000000005', '40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000006', 'SGN', 'HAN', 'VN', 'Vietnam Airlines', '50000000-0000-4000-8000-000000000001', ARRAY['VN220'], 130, 1160, '{1,2,3,4,5,6,7}', ARRAY['A321'], '10000000-0000-4000-8000-000000000001', 'route-sgn-han-vn', TRUE),
('70000000-0000-4000-8000-000000000006', '40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000003', 'SGN', 'BKK', 'TG', 'Thai Airways', '50000000-0000-4000-8000-000000000003', ARRAY['TG551'], 90, 717, '{1,3,5,7}', ARRAY['A320'], '10000000-0000-4000-8000-000000000001', 'route-sgn-bkk-tg', TRUE),
('70000000-0000-4000-8000-000000000007', '40000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000003', 'SGN', 'BKK', 'VJ', 'VietJet Air', '50000000-0000-4000-8000-000000000004', ARRAY['VJ801'], 95, 717, '{2,4,6}', ARRAY['A321'], '10000000-0000-4000-8000-000000000001', 'route-sgn-bkk-vj', TRUE),
('70000000-0000-4000-8000-000000000008', '40000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000002', 'BKK', 'SIN', 'SQ', 'Singapore Airlines', '50000000-0000-4000-8000-000000000002', ARRAY['SQ711'], 150, 1418, '{1,2,3,4,5,6,7}', ARRAY['B787'], '10000000-0000-4000-8000-000000000001', 'route-bkk-sin-sq', TRUE),
('70000000-0000-4000-8000-000000000009', '40000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000004', 'BKK', 'LHR', 'TG', 'Thai Airways', '50000000-0000-4000-8000-000000000003', ARRAY['TG910'], 760, 9580, '{1,3,5,7}', ARRAY['B777'], '10000000-0000-4000-8000-000000000001', 'route-bkk-lhr-tg', TRUE),
('70000000-0000-4000-8000-000000000010', '40000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000005', 'BKK', 'HND', 'TG', 'Thai Airways', '50000000-0000-4000-8000-000000000003', ARRAY['TG660'], 360, 4580, '{1,2,3,4,5,6,7}', ARRAY['A350'], '10000000-0000-4000-8000-000000000001', 'route-bkk-hnd-tg', TRUE),
('70000000-0000-4000-8000-000000000011', '40000000-0000-4000-8000-000000000007', '40000000-0000-4000-8000-000000000009', 'DMK', 'NRT', 'VJ', 'VietJet Air', '50000000-0000-4000-8000-000000000004', ARRAY['VJ933'], 370, 4650, '{2,4,6}', ARRAY['A321'], '10000000-0000-4000-8000-000000000001', 'route-dmk-nrt-vj', TRUE),
('70000000-0000-4000-8000-000000000012', '40000000-0000-4000-8000-000000000006', '40000000-0000-4000-8000-000000000002', 'HAN', 'SIN', 'VN', 'Vietnam Airlines', '50000000-0000-4000-8000-000000000001', ARRAY['VN661'], 210, 2207, '{1,3,5,7}', ARRAY['A321'], '10000000-0000-4000-8000-000000000001', 'route-han-sin-vn', TRUE),
('70000000-0000-4000-8000-000000000013', '40000000-0000-4000-8000-000000000005', '40000000-0000-4000-8000-000000000002', 'HND', 'SIN', 'JL', 'Japan Airlines', '50000000-0000-4000-8000-000000000006', ARRAY['JL35'], 430, 5310, '{1,2,3,4,5,6,7}', ARRAY['B787'], '10000000-0000-4000-8000-000000000001', 'route-hnd-sin-jl', TRUE),
('70000000-0000-4000-8000-000000000014', '40000000-0000-4000-8000-000000000004', '40000000-0000-4000-8000-000000000001', 'LHR', 'SGN', 'BA', 'British Airways', '50000000-0000-4000-8000-000000000005', ARRAY['BA63'], 760, 10200, '{1,5}', ARRAY['B787'], '10000000-0000-4000-8000-000000000001', 'route-lhr-sgn-ba', TRUE),
('70000000-0000-4000-8000-000000000015', '40000000-0000-4000-8000-000000000008', '40000000-0000-4000-8000-000000000001', 'LGW', 'SGN', 'BA', 'British Airways', '50000000-0000-4000-8000-000000000005', ARRAY['BA61'], 780, 10240, '{2,6}', ARRAY['B787'], '10000000-0000-4000-8000-000000000001', 'route-lgw-sgn-ba', TRUE),
('70000000-0000-4000-8000-000000000016', '40000000-0000-4000-8000-000000000009', '40000000-0000-4000-8000-000000000004', 'NRT', 'LHR', 'JL', 'Japan Airlines', '50000000-0000-4000-8000-000000000006', ARRAY['JL41'], 855, 9585, '{3,7}', ARRAY['B787'], '10000000-0000-4000-8000-000000000001', 'route-nrt-lhr-jl', TRUE);

INSERT INTO public.flight_route_prices (
  id, origin_city_id, destination_city_id, origin_airport_id, destination_airport_id,
  canonical_airline_id, provider_airline_iata, observation_type, trip_type, direct,
  transfer_count, observed_amount, currency_code, market_code, locale, departure_date,
  source_id, provider_code, source_record_id, observed_at, valid_until,
  affiliate_path, status
)
VALUES
  (
    '60000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000004',
    '40000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000004',
    '50000000-0000-4000-8000-000000000001',
    'VN', 'cached_fare', 'one_way', TRUE, 0, 392, 'USD', 'us', 'en-GB',
    CURRENT_DATE + 30, '10000000-0000-4000-8000-000000000001', 'fixture',
    'price-sgn-lhr', now(), now() + INTERVAL '6 days', '/search/SGN-LON', 'published'
  ),
  (
    '60000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    '50000000-0000-4000-8000-000000000002',
    'SQ', 'cached_fare', 'one_way', TRUE, 0, 98, 'USD', 'us', 'en-GB',
    CURRENT_DATE + 30, '10000000-0000-4000-8000-000000000001', 'fixture',
    'price-sgn-sin', now(), now() + INTERVAL '6 days', '/search/SGN-SIN', 'published'
  );

INSERT INTO public.flight_route_prices (
  id, origin_city_id, destination_city_id, origin_airport_id, destination_airport_id,
  canonical_airline_id, provider_airline_iata, observation_type, trip_type, direct,
  transfer_count, observed_amount, currency_code, market_code, locale, departure_date,
  source_id, provider_code, source_record_id, observed_at, valid_until,
  affiliate_path, status
)
VALUES
  ('60000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000006','40000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000006','50000000-0000-4000-8000-000000000001','VN','cached_fare','one_way',TRUE,0,55,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-sgn-han-vn',now(),now() + INTERVAL '6 days','/search/SGN-HAN','published'),
  ('60000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000003','50000000-0000-4000-8000-000000000003','TG','cached_fare','one_way',TRUE,0,120,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-sgn-bkk-tg',now(),now() + INTERVAL '6 days','/search/SGN-BKK','published'),
  ('60000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000003','50000000-0000-4000-8000-000000000004','VJ','cached_fare','one_way',TRUE,0,75,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-sgn-bkk-vj',now(),now() + INTERVAL '6 days','/search/SGN-BKK','published'),
  ('60000000-0000-4000-8000-000000000006','30000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000002','SQ','cached_fare','one_way',TRUE,0,110,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-bkk-sin-sq',now(),now() + INTERVAL '6 days','/search/BKK-SIN','published'),
  ('60000000-0000-4000-8000-000000000007','30000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000004','50000000-0000-4000-8000-000000000003','TG','cached_fare','one_way',TRUE,0,500,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-bkk-lhr-tg',now(),now() + INTERVAL '6 days','/search/BKK-LHR','published'),
  ('60000000-0000-4000-8000-000000000008','30000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000005','50000000-0000-4000-8000-000000000003','TG','cached_fare','one_way',TRUE,0,250,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-bkk-hnd-tg',now(),now() + INTERVAL '6 days','/search/BKK-HND','published'),
  ('60000000-0000-4000-8000-000000000009','30000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000007','40000000-0000-4000-8000-000000000009','50000000-0000-4000-8000-000000000004','VJ','cached_fare','one_way',TRUE,0,190,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-dmk-nrt-vj',now(),now() + INTERVAL '6 days','/search/DMK-NRT','published'),
  ('60000000-0000-4000-8000-000000000010','30000000-0000-4000-8000-000000000006','30000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000006','40000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000001','VN','cached_fare','one_way',TRUE,0,140,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-han-sin-vn',now(),now() + INTERVAL '6 days','/search/HAN-SIN','published'),
  ('60000000-0000-4000-8000-000000000011','30000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000006','JL','cached_fare','one_way',TRUE,0,220,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-hnd-sin-jl',now(),now() + INTERVAL '6 days','/search/HND-SIN','published'),
  ('60000000-0000-4000-8000-000000000012','30000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000005','BA','cached_fare','one_way',TRUE,0,450,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-lhr-sgn-ba',now(),now() + INTERVAL '6 days','/search/LHR-SGN','published'),
  ('60000000-0000-4000-8000-000000000013','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000004',NULL,NULL,'cached_fare','one_way',FALSE,1,320,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-sgn-lhr-one-stop',now(),now() + INTERVAL '6 days','/search/SGN-LHR','published'),
  ('60000000-0000-4000-8000-000000000014','30000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000004',NULL,NULL,'cached_fare','one_way',FALSE,1,420,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-bkk-lhr-one-stop',now(),now() + INTERVAL '6 days','/search/BKK-LHR','published'),
  ('60000000-0000-4000-8000-000000000015','30000000-0000-4000-8000-000000000006','30000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000006','40000000-0000-4000-8000-000000000004',NULL,NULL,'cached_fare','one_way',FALSE,1,480,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-han-lhr-one-stop',now(),now() + INTERVAL '6 days','/search/HAN-LHR','published'),
  ('60000000-0000-4000-8000-000000000016','30000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000004',NULL,NULL,'cached_fare','one_way',FALSE,1,600,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-hnd-lhr-one-stop',now(),now() + INTERVAL '6 days','/search/HND-LHR','published'),
  ('60000000-0000-4000-8000-000000000017','30000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000008','40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000005','BA','cached_fare','one_way',TRUE,0,430,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-lgw-sgn-ba',now(),now() + INTERVAL '6 days','/search/LGW-SGN','published'),
  ('60000000-0000-4000-8000-000000000018','30000000-0000-4000-8000-000000000005','30000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000009','40000000-0000-4000-8000-000000000004','50000000-0000-4000-8000-000000000006','JL','cached_fare','one_way',TRUE,0,520,'USD','us','en-GB',CURRENT_DATE + 30,'10000000-0000-4000-8000-000000000001','fixture','price-nrt-lhr-jl',now(),now() + INTERVAL '6 days','/search/NRT-LHR','published');

INSERT INTO public.pseo_pages (id,page_type,entity_key,locale,canonical_path,display_title,status,is_indexable,noindex_reason,source_freshness_at) VALUES
('81000000-0000-4000-8000-000000000001','city','ho-chi-minh-city','en-GB','/flights-from/ho-chi-minh-city','Flights from Ho Chi Minh City','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000002','airport','sgn','en-GB','/airports/tan-son-nhat-sgn','Tan Son Nhat Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000003','city_route','ho-chi-minh-city-to-london','en-GB','/flights/ho-chi-minh-city-to-london','Ho Chi Minh City to London flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000004','city_route','ho-chi-minh-city-to-singapore','en-GB','/flights/ho-chi-minh-city-to-singapore','Ho Chi Minh City to Singapore flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000006','city','bangkok','en-GB','/flights-from/bangkok','Flights from Bangkok','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000007','city','hanoi','en-GB','/flights-from/hanoi','Flights from Hanoi','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000008','city','singapore','en-GB','/flights-from/singapore','Flights from Singapore','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000009','city','london','en-GB','/flights-from/london','Flights from London','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000010','city','tokyo','en-GB','/flights-from/tokyo','Flights from Tokyo','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000011','airport','sin','en-GB','/airports/singapore-changi-sin','Singapore Changi Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000012','airport','bkk','en-GB','/airports/suvarnabhumi-bkk','Suvarnabhumi Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000013','airport','dmk','en-GB','/airports/don-mueang-dmk','Don Mueang Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000014','airport','lhr','en-GB','/airports/heathrow-lhr','Heathrow Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000015','airport','lgw','en-GB','/airports/gatwick-lgw','Gatwick Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000016','airport','hnd','en-GB','/airports/haneda-hnd','Haneda Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000017','airport','nrt','en-GB','/airports/narita-nrt','Narita Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000018','airport','han','en-GB','/airports/noi-bai-han','Noi Bai Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000020','city_route','ho-chi-minh-city-to-hanoi','en-GB','/flights/ho-chi-minh-city-to-hanoi','Ho Chi Minh City to Hanoi flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000021','city_route','ho-chi-minh-city-to-bangkok','en-GB','/flights/ho-chi-minh-city-to-bangkok','Ho Chi Minh City to Bangkok flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000022','city_route','bangkok-to-singapore','en-GB','/flights/bangkok-to-singapore','Bangkok to Singapore flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000023','city_route','bangkok-to-london','en-GB','/flights/bangkok-to-london','Bangkok to London flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000024','city_route','bangkok-to-tokyo','en-GB','/flights/bangkok-to-tokyo','Bangkok to Tokyo flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000025','city_route','hanoi-to-singapore','en-GB','/flights/hanoi-to-singapore','Hanoi to Singapore flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000026','city_route','hanoi-to-london','en-GB','/flights/hanoi-to-london','Hanoi to London flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000027','city_route','tokyo-to-singapore','en-GB','/flights/tokyo-to-singapore','Tokyo to Singapore flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000028','city_route','tokyo-to-london','en-GB','/flights/tokyo-to-london','Tokyo to London flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000029','city_route','london-to-ho-chi-minh-city','en-GB','/flights/london-to-ho-chi-minh-city','London to Ho Chi Minh City flights','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000030','city_route','singapore-to-london','en-GB','/flights/singapore-to-london','Singapore to London flights','published',false,'development_fixture',now());

INSERT INTO public.city_pages (pseo_page_id,city_id,locale,route_direction,primary_airport_id,content,content_reviewed_at) VALUES
('81000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','en-GB','outbound','40000000-0000-4000-8000-000000000001',jsonb_build_object(
  'seo', jsonb_build_object(
    'h1', 'Direct Flights from Ho Chi Minh City (SGN)',
    'subheadline', 'Explore nonstop routes across Southeast Asia, East Asia, and Europe',
    'title', 'Direct Flights from Ho Chi Minh City: Nonstop Routes & Airlines | Tripways',
    'meta_description', 'Discover all nonstop and connecting flights departing from Ho Chi Minh City (SGN). Compare airlines, flight times, and live schedule data.',
    'intro', 'Ho Chi Minh City is Vietnam primary economic engine and busiest aviation gateway. From Tan Son Nhat International Airport (SGN), passengers can connect directly to over 30 international destinations and every major domestic hub.'
  ),
  'faqs', jsonb_build_array(
    jsonb_build_object('question', 'Which airlines operate the most international flights from Ho Chi Minh City?', 'answer', 'Vietnam Airlines and Vietjet Air operate the widest network of international routes, supplemented by regional carriers like Singapore Airlines, Thai Airways, and Cathay Pacific.'),
    jsonb_build_object('question', 'How early should I arrive at SGN for international departures?', 'answer', 'It is strongly recommended to arrive at least 3 hours prior to scheduled departure due to immigration and security screening queues at Terminal 2.'),
    jsonb_build_object('question', 'What is the cheapest month to fly out of Ho Chi Minh City?', 'answer', 'Fares are generally lowest during shoulder seasons in September to November and March to May, avoiding the peak Lunar New Year (Tet) travel period.')
  ),
  'internal_link_groups', jsonb_build_array(
    jsonb_build_object('cluster', 'airports', 'links', jsonb_build_array(
      jsonb_build_object('anchor_text', 'Tan Son Nhat Airport Guide (SGN)', 'path', '/airports/tan-son-nhat-sgn')
    )),
    jsonb_build_object('cluster', 'popular_routes', 'links', jsonb_build_array(
      jsonb_build_object('anchor_text', 'Flights to Singapore', 'path', '/flights/ho-chi-minh-city-to-singapore'),
      jsonb_build_object('anchor_text', 'Flights to London', 'path', '/flights/ho-chi-minh-city-to-london')
    ))
  )
), now());

INSERT INTO public.city_pages (
  pseo_page_id, city_id, locale, route_direction, primary_airport_id, content, content_reviewed_at
)
VALUES
  ('81000000-0000-4000-8000-000000000006','30000000-0000-4000-8000-000000000003','en-GB','outbound','40000000-0000-4000-8000-000000000003','{}'::JSONB,now()),
  ('81000000-0000-4000-8000-000000000007','30000000-0000-4000-8000-000000000006','en-GB','outbound','40000000-0000-4000-8000-000000000006','{}'::JSONB,now()),
  ('81000000-0000-4000-8000-000000000008','30000000-0000-4000-8000-000000000002','en-GB','outbound','40000000-0000-4000-8000-000000000002','{}'::JSONB,now()),
  ('81000000-0000-4000-8000-000000000009','30000000-0000-4000-8000-000000000004','en-GB','outbound','40000000-0000-4000-8000-000000000004','{}'::JSONB,now()),
  ('81000000-0000-4000-8000-000000000010','30000000-0000-4000-8000-000000000005','en-GB','outbound','40000000-0000-4000-8000-000000000005','{}'::JSONB,now());

INSERT INTO public.airport_pages (pseo_page_id,airport_id,locale,content,content_reviewed_at) VALUES
('81000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000001','en-GB',jsonb_build_object(
  'seo', jsonb_build_object('h1', 'Tan Son Nhat International Airport (SGN) Guide', 'subheadline', 'Vietnam busiest aviation hub: terminals, transport & essential tips', 'title', 'SGN Airport Guide: Tan Son Nhat Terminals & Transit | Tripways', 'meta_description', 'Complete passenger transit and terminal guide for Tan Son Nhat Airport (SGN) in Ho Chi Minh City. Includes express bus routes, Grab pick-up points, lounge access, and departure tips.'),
  'orientation', jsonb_build_object('intro', 'Welcome to Tan Son Nhat International Airport (SGN), the main international gateway to Southern Vietnam located just 8 km north of downtown Ho Chi Minh City.', 'summary', 'With two connected terminals handling domestic (T1) and international (T2) flights, SGN accommodates over 38 million passengers annually.', 'city_distance_km', 8, 'terminal_count', 2),
  'quick_answers', jsonb_build_object('default_transport', jsonb_build_object('name', 'Airport Bus 109 / Grab Taxi', 'typical_minutes', jsonb_build_object('min', 30, 'max', 60), 'estimated_price', jsonb_build_object('min', 20000, 'max', 150000, 'currency', 'VND')), 'city_distance_km', 8, 'terminal_count', 2),
  'arrival', jsonb_build_object(
    'summary', 'Arrival procedures for domestic and international passengers landing at Tan Son Nhat.',
    'steps', jsonb_build_array(
      jsonb_build_object('audience', 'international', 'title', '1. Passport Control & Visa', 'body', 'Follow arrival signage to Ground Floor passport control. Visa-on-arrival counter is situated directly before the main passport control desks.'),
      jsonb_build_object('audience', 'international', 'title', '2. Baggage Reclaim & Customs', 'body', 'Retrieve checked baggage from belts 1-6. All international arrivals must pass customs X-ray screening before exiting to the public arrival hall.'),
      jsonb_build_object('audience', 'all', 'title', '3. SIM Cards, Currency & Transport', 'body', 'Official telecom kiosks (Viettel, Vinaphone) and licensed currency exchange booths line the exit lobby. Proceed to Lane B or D for app-based taxis.')
    )
  ),
  'departure', jsonb_build_object(
    'summary', 'Departure check-in, security, and boarding gates guide.',
    'steps', jsonb_build_array(
      jsonb_build_object('audience', 'all', 'title', '1. Terminal & Check-in Desk', 'body', 'International flights depart from T2 2nd Floor; domestic flights depart from T1. Online check-in bag drop closes 60 minutes before scheduled departure.'),
      jsonb_build_object('audience', 'international', 'title', '2. Immigration & Security Check', 'body', 'Automated e-Gates are available for eligible biometric passport holders. Security requires laptops and liquids placed in separate trays.'),
      jsonb_build_object('audience', 'all', 'title', '3. Boarding Gates & VAT Refund', 'body', 'VAT refund verification counter is located airside near Gate 17. Boarding commences 40 minutes prior to departure.')
    )
  ),
  'transport', jsonb_build_array(
    jsonb_build_object(
      'direction', 'from_airport', 'type', 'bus', 'name', 'Bus 109 Express', 'destination_label', 'District 1 (Ben Thanh Market)',
      'summary', 'Air-conditioned yellow express bus directly connecting SGN to central Saigon hotels.', 'duration', jsonb_build_object('min_minutes', 30, 'max_minutes', 45),
      'estimated_price', jsonb_build_object('min', 20000, 'max', 20000, 'currency', 'VND'), 'operating_hours_summary', '05:30–01:00 (every 20 mins)',
      'pickup_location_summary', 'Column 12, Terminal 2 Ground Floor (outside arrival gate)', 'best_for_label', 'Budget & solo travelers',
      'luggage_summary', 'Spacious low-floor luggage racks', 'accessibility_summary', 'Wheelchair ramp available', 'booking_url', NULL,
      'source_url', 'https://example.com/bus109', 'last_verified_at', '2026-08-04'
    ),
    jsonb_build_object(
      'direction', 'from_airport', 'type', 'taxi', 'name', 'GrabCar / Be', 'destination_label', 'Door-to-door (Ho Chi Minh City)',
      'summary', 'App-based ride-hailing with upfront transparent fares without risk of meter tampering.', 'duration', jsonb_build_object('min_minutes', 30, 'max_minutes', 60),
      'estimated_price', jsonb_build_object('min', 120000, 'max', 220000, 'currency', 'VND'), 'operating_hours_summary', '24 hours daily',
      'pickup_location_summary', 'Lane D / TCP Parking Garage 3rd-5th floors', 'best_for_label', 'Families with heavy luggage',
      'luggage_summary', 'Standard sedan or 7-seat SUV trunk', 'accessibility_summary', NULL, 'booking_url', NULL,
      'source_url', 'https://example.com/grab', 'last_verified_at', '2026-08-04'
    ),
    jsonb_build_object(
      'direction', 'to_airport', 'type', 'taxi', 'name', 'Metered Taxi (Vinasun / Mai Linh)', 'destination_label', 'Tan Son Nhat Departure Hall (T1/T2)',
      'summary', 'Reputable traditional metered taxi companies drop off right outside departure check-in doors.', 'duration', jsonb_build_object('min_minutes', 25, 'max_minutes', 50),
      'estimated_price', jsonb_build_object('min', 130000, 'max', 200000, 'currency', 'VND'), 'operating_hours_summary', '24 hours',
      'pickup_location_summary', 'Flag down in city or call dispatch hotlines', 'best_for_label', 'Convenient early morning departures',
      'luggage_summary', 'Full trunk capacity', 'accessibility_summary', NULL, 'booking_url', NULL,
      'source_url', 'https://example.com/taxi', 'last_verified_at', '2026-08-04'
    )
  ),
  'terminals', jsonb_build_array(
    jsonb_build_object('code', 'T1', 'name', 'Domestic Terminal (Vietnam Airlines, Vietjet, Bamboo)', 'status', 'active'),
    jsonb_build_object('code', 'T2', 'name', 'International Terminal (All foreign carriers & intl flights)', 'status', 'active')
  ),
  'facilities', jsonb_build_array(
    jsonb_build_object('category', 'Connectivity', 'name', 'Tourist eSIM & SIM Cards', 'summary', 'Official Viettel and Vinaphone counters at T2 arrivals lobby offering 4G/5G data packages from 200,000 VND.'),
    jsonb_build_object('category', 'Finance', 'name', 'ATMs & Currency Exchange', 'summary', 'Vietcombank, BIDV, and HSBC ATMs located in both departure and arrival lobbies.'),
    jsonb_build_object('category', 'Comfort', 'name', 'Free High-Speed Wi-Fi & Charging', 'summary', 'Complimentary "FreeWifi TanSonNhat Airport" available throughout both passenger terminals.')
  ),
  'lounges', jsonb_build_array(
    jsonb_build_object(
      'name', 'Lotus Lounge (T2 International)', 'location_summary', 'Terminal 2 Airside, near Gate 18', 'location_type', 'airside',
      'access_summary', 'Business Class passengers, SkyTeam Elite Plus, Lotusmiles Platinum, or walk-in lounge pass (~$35 USD)', 'operating_hours_summary', '24 hours',
      'amenities', ARRAY['high_speed_wifi', 'hot_buffet', 'showers', 'massage_chairs', 'flight_monitors'], 'estimated_price', jsonb_build_object('min', 35, 'max', 45, 'currency', 'USD'),
      'affiliate_url', NULL, 'source_url', 'https://vietnamairlines.com', 'last_verified_at', '2026-08-04'
    ),
    jsonb_build_object(
      'name', 'Le Saigonnais Business Lounge', 'location_summary', 'Terminal 1 Airside (Domestic) & Terminal 2 Gate 11 (Intl)', 'location_type', 'airside',
      'access_summary', 'Priority Pass, DragonPass, and selected airline premium passengers', 'operating_hours_summary', '04:30–23:00',
      'amenities', ARRAY['wifi', 'asian_buffet', 'quiet_zone', 'beverages'], 'estimated_price', jsonb_build_object('min', 30, 'max', 40, 'currency', 'USD'),
      'affiliate_url', NULL, 'source_url', 'https://example.com/lesaigonnais', 'last_verified_at', '2026-08-04'
    )
  ),
  'notices', jsonb_build_array(
    jsonb_build_object('title', 'Terminal T3 Construction Underway', 'body', 'A brand new passenger terminal (T3) is slated for domestic expansion. Expect periodic road diversions around Truong Son entrance.'),
    jsonb_build_object('title', 'Beware Unofficial Taxi Touts', 'body', 'Ignore unsolicited touts inside the arrival hall claiming to be Grab or metered drivers. Only board cars in official queue lanes.')
  ),
  'faqs', jsonb_build_array(
    jsonb_build_object('question', 'How far is Tan Son Nhat Airport from District 1?', 'answer', 'It is roughly 8 km north of District 1. Travel time is typically 30 to 50 minutes depending on rush-hour traffic.'),
    jsonb_build_object('question', 'Can I walk between Terminal 1 and Terminal 2?', 'answer', 'Yes, a sheltered pedestrian corridor connects Domestic Terminal 1 and International Terminal 2. The walk takes approximately 5 minutes.'),
    jsonb_build_object('question', 'Where do I catch a Grab car at SGN?', 'answer', 'For Terminal 2 arrivals, walk across Lane B to the ground floor pick-up bays or the multi-level TCP parking structure.')
  ),
  'internal_link_groups', jsonb_build_array(
    jsonb_build_object('cluster', 'city', 'links', jsonb_build_array(
      jsonb_build_object('anchor_text', 'Flights from Ho Chi Minh City', 'path', '/flights-from/ho-chi-minh-city')
    )),
    jsonb_build_object('cluster', 'routes', 'links', jsonb_build_array(
      jsonb_build_object('anchor_text', 'Flights to Singapore (SIN)', 'path', '/flights/ho-chi-minh-city-to-singapore'),
      jsonb_build_object('anchor_text', 'Flights to London (LHR)', 'path', '/flights/ho-chi-minh-city-to-london')
    ))
  )
), now());

INSERT INTO public.airport_pages (
  pseo_page_id, airport_id, locale, content, content_reviewed_at
)
SELECT
  fixture.pseo_page_id,
  fixture.airport_id,
  'en-GB',
  jsonb_build_object(
    'seo', jsonb_build_object(
      'h1', fixture.airport_name || ' (' || fixture.iata || ') Guide',
      'subheadline', 'Terminals, transport, routes, and practical travel information',
      'title', fixture.iata || ' Airport Guide | Tripways',
      'meta_description', 'Plan your journey through ' || fixture.airport_name || '.'
    ),
    'orientation', jsonb_build_object(
      'intro', fixture.airport_name || ' serves the Tripways deterministic local test network.',
      'summary', 'Use this development fixture to test airport content, route filters, and maps.',
      'city_distance_km', 20,
      'terminal_count', 2
    ),
    'quick_answers', jsonb_build_object(
      'default_transport', NULL,
      'city_distance_km', 20,
      'terminal_count', 2
    ),
    'arrival', jsonb_build_object('summary', 'Follow airport signs to arrivals.', 'steps', '[]'::JSONB),
    'departure', jsonb_build_object('summary', 'Check in before proceeding to security.', 'steps', '[]'::JSONB),
    'transport', '[]'::JSONB,
    'terminals', '[]'::JSONB,
    'facilities', '[]'::JSONB,
    'lounges', '[]'::JSONB,
    'notices', '[]'::JSONB,
    'faqs', '[]'::JSONB,
    'internal_link_groups', '[]'::JSONB
  ),
  now()
FROM (
  VALUES
    ('81000000-0000-4000-8000-000000000011'::UUID,'40000000-0000-4000-8000-000000000002'::UUID,'SIN','Singapore Changi Airport'),
    ('81000000-0000-4000-8000-000000000012'::UUID,'40000000-0000-4000-8000-000000000003'::UUID,'BKK','Suvarnabhumi Airport'),
    ('81000000-0000-4000-8000-000000000013'::UUID,'40000000-0000-4000-8000-000000000007'::UUID,'DMK','Don Mueang International Airport'),
    ('81000000-0000-4000-8000-000000000014'::UUID,'40000000-0000-4000-8000-000000000004'::UUID,'LHR','Heathrow Airport'),
    ('81000000-0000-4000-8000-000000000015'::UUID,'40000000-0000-4000-8000-000000000008'::UUID,'LGW','Gatwick Airport'),
    ('81000000-0000-4000-8000-000000000016'::UUID,'40000000-0000-4000-8000-000000000005'::UUID,'HND','Haneda Airport'),
    ('81000000-0000-4000-8000-000000000017'::UUID,'40000000-0000-4000-8000-000000000009'::UUID,'NRT','Narita International Airport'),
    ('81000000-0000-4000-8000-000000000018'::UUID,'40000000-0000-4000-8000-000000000006'::UUID,'HAN','Noi Bai International Airport')
) AS fixture(pseo_page_id, airport_id, iata, airport_name);

INSERT INTO public.route_pages (pseo_page_id,origin_city_id,destination_city_id,locale,content,content_reviewed_at) VALUES
('81000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004','en-GB',jsonb_build_object(
  'seo', jsonb_build_object(
    'h1', 'Flights from Ho Chi Minh City to London',
    'subheadline', 'Compare direct flights and 1-stop connecting schedules from SGN to LON',
    'title', 'Ho Chi Minh City to London Flights: Nonstop & 1-Stop Options | Tripways',
    'meta_description', 'Compare direct flights and one-stop connections between Ho Chi Minh City (SGN) and London (LHR/LGW). Find airlines, flight durations, and booking insights.',
    'intro', 'Flying from Ho Chi Minh City to London connects Vietnam Southern metropolis with the capital of the United Kingdom. Direct flights take approximately 13 hours with Vietnam Airlines, while convenient one-stop connections are offered via Doha, Dubai, and Singapore.'
  ),
  'travel_facts', jsonb_build_array(
    jsonb_build_object('type', 'distance', 'title', 'Flight Distance', 'body', 'The flight distance between Ho Chi Minh City (SGN) and London (LHR) is approximately 10,210 km (6,344 miles).'),
    jsonb_build_object('type', 'duration', 'title', 'Direct Flight Duration', 'body', 'Nonstop flights take approximately 13 hours 15 minutes heading westbound.'),
    jsonb_build_object('type', 'airlines', 'title', 'Operating Airlines', 'body', 'Vietnam Airlines operates direct non-stop flights to London Heathrow (LHR). Qatar Airways, Emirates, and Singapore Airlines offer competitive 1-stop routes.')
  ),
  'editorial_sections', jsonb_build_array(
    jsonb_build_object('type', 'guide', 'heading', 'Direct vs One-Stop Options', 'body', 'Direct flights save between 3 and 7 hours of total journey time. However, one-stop itineraries via the Middle East frequently offer significant fare discounts and modern wide-body aircraft comfort.'),
    jsonb_build_object('type', 'tips', 'heading', 'Best Time to Book', 'body', 'Book at least 8-12 weeks in advance for summer travel (June-August) and the Christmas holiday period to secure the best fares.')
  ),
  'faqs', jsonb_build_array(
    jsonb_build_object('question', 'How many airlines fly direct from Ho Chi Minh City to London?', 'answer', 'Vietnam Airlines is currently the sole carrier operating direct nonstop flights between Ho Chi Minh City (SGN) and London Heathrow (LHR).'),
    jsonb_build_object('question', 'What is the fastest travel time between SGN and London?', 'answer', 'The fastest nonstop flight takes roughly 13 hours 15 minutes.')
  ),
  'internal_link_groups', jsonb_build_array(
    jsonb_build_object('cluster', 'city', 'links', jsonb_build_array(
      jsonb_build_object('anchor_text', 'Flights from Ho Chi Minh City', 'path', '/flights-from/ho-chi-minh-city')
    ))
  )
), now()),
('81000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','en-GB',jsonb_build_object(
  'seo', jsonb_build_object(
    'h1', 'Flights from Ho Chi Minh City to Singapore',
    'subheadline', 'Compare daily nonstop flights between SGN and SIN from top airlines',
    'title', 'Ho Chi Minh City to Singapore Flights: Direct Routes & Schedules | Tripways',
    'meta_description', 'Find all nonstop flights from Ho Chi Minh City (SGN) to Singapore Changi (SIN). Compare flight schedules, prices, airlines, and airport transit info.',
    'intro', 'The Ho Chi Minh City to Singapore air corridor is one of Southeast Asia busiest business and leisure routes, spanning roughly 1,090 km with average flight times under two hours.'
  ),
  'travel_facts', jsonb_build_array(
    jsonb_build_object('type', 'duration', 'title', 'Flight Time', 'body', 'Direct nonstop flights take roughly 2 hours to 2 hours 15 minutes.'),
    jsonb_build_object('type', 'distance', 'title', 'Route Distance', 'body', 'The flight distance from Tan Son Nhat (SGN) to Singapore Changi (SIN) is approximately 1,090 km (677 miles).'),
    jsonb_build_object('type', 'frequency', 'title', 'Flight Frequency', 'body', 'There are multiple daily departures operated by full-service and low-cost carriers.')
  ),
  'editorial_sections', jsonb_build_array(
    jsonb_build_object('type', 'comparison', 'heading', 'Airlines Flying Between SGN and SIN', 'body', 'Singapore Airlines and Vietnam Airlines offer premium full-service experiences including meals and checked luggage. Budget travelers can choose Scoot or Vietjet Air for lower base fares.'),
    jsonb_build_object('type', 'arrival_guide', 'heading', 'Arriving at Singapore Changi (SIN)', 'body', 'Singapore Changi Airport features four interconnected terminals. All foreign visitors must submit the electronic SG Arrival Card (SGAC) within 3 days prior to arrival.')
  ),
  'faqs', jsonb_build_array(
    jsonb_build_object('question', 'How long is the flight from Ho Chi Minh City to Singapore?', 'answer', 'A direct flight from Tan Son Nhat Airport (SGN) to Singapore Changi (SIN) takes approximately 2 hours and 5 minutes.'),
    jsonb_build_object('question', 'Do I need a visa to travel from Vietnam to Singapore?', 'answer', 'Vietnamese passport holders are eligible for visa-free entry to Singapore for stays up to 30 days. An electronic SG Arrival Card submission is mandatory.'),
    jsonb_build_object('question', 'Which terminal does the flight land at in Singapore?', 'answer', 'Singapore Airlines and Scoot generally arrive at Terminal 1, 2, or 3, while Vietjet Air typically operates from Terminal 4.')
  ),
  'internal_link_groups', jsonb_build_array(
    jsonb_build_object('cluster', 'city', 'links', jsonb_build_array(
      jsonb_build_object('anchor_text', 'Flights from Ho Chi Minh City', 'path', '/flights-from/ho-chi-minh-city')
    )),
    jsonb_build_object('cluster', 'airports', 'links', jsonb_build_array(
      jsonb_build_object('anchor_text', 'Tan Son Nhat Airport Guide', 'path', '/airports/tan-son-nhat-sgn')
    ))
  )
), now());

INSERT INTO public.route_pages (
  pseo_page_id, origin_city_id, destination_city_id, locale, content, content_reviewed_at
)
SELECT
  fixture.pseo_page_id,
  fixture.origin_city_id,
  fixture.destination_city_id,
  'en-GB',
  jsonb_build_object(
    'seo', jsonb_build_object(
      'h1', 'Flights from ' || fixture.origin_name || ' to ' || fixture.destination_name,
      'subheadline', 'Compare deterministic direct and one-stop route fixtures',
      'title', fixture.origin_name || ' to ' || fixture.destination_name || ' Flights | Tripways',
      'meta_description', 'Compare local fixture routes from ' || fixture.origin_name || ' to ' || fixture.destination_name || '.',
      'intro', 'This development-only route page covers search, filters, prices, and map rendering.'
    ),
    'travel_facts', '[]'::JSONB,
    'editorial_sections', '[]'::JSONB,
    'faqs', '[]'::JSONB,
    'internal_link_groups', '[]'::JSONB
  ),
  now()
FROM (
  VALUES
    ('81000000-0000-4000-8000-000000000020'::UUID,'30000000-0000-4000-8000-000000000001'::UUID,'30000000-0000-4000-8000-000000000006'::UUID,'Ho Chi Minh City','Hanoi'),
    ('81000000-0000-4000-8000-000000000021'::UUID,'30000000-0000-4000-8000-000000000001'::UUID,'30000000-0000-4000-8000-000000000003'::UUID,'Ho Chi Minh City','Bangkok'),
    ('81000000-0000-4000-8000-000000000022'::UUID,'30000000-0000-4000-8000-000000000003'::UUID,'30000000-0000-4000-8000-000000000002'::UUID,'Bangkok','Singapore'),
    ('81000000-0000-4000-8000-000000000023'::UUID,'30000000-0000-4000-8000-000000000003'::UUID,'30000000-0000-4000-8000-000000000004'::UUID,'Bangkok','London'),
    ('81000000-0000-4000-8000-000000000024'::UUID,'30000000-0000-4000-8000-000000000003'::UUID,'30000000-0000-4000-8000-000000000005'::UUID,'Bangkok','Tokyo'),
    ('81000000-0000-4000-8000-000000000025'::UUID,'30000000-0000-4000-8000-000000000006'::UUID,'30000000-0000-4000-8000-000000000002'::UUID,'Hanoi','Singapore'),
    ('81000000-0000-4000-8000-000000000026'::UUID,'30000000-0000-4000-8000-000000000006'::UUID,'30000000-0000-4000-8000-000000000004'::UUID,'Hanoi','London'),
    ('81000000-0000-4000-8000-000000000027'::UUID,'30000000-0000-4000-8000-000000000005'::UUID,'30000000-0000-4000-8000-000000000002'::UUID,'Tokyo','Singapore'),
    ('81000000-0000-4000-8000-000000000028'::UUID,'30000000-0000-4000-8000-000000000005'::UUID,'30000000-0000-4000-8000-000000000004'::UUID,'Tokyo','London'),
    ('81000000-0000-4000-8000-000000000029'::UUID,'30000000-0000-4000-8000-000000000004'::UUID,'30000000-0000-4000-8000-000000000001'::UUID,'London','Ho Chi Minh City'),
    ('81000000-0000-4000-8000-000000000030'::UUID,'30000000-0000-4000-8000-000000000002'::UUID,'30000000-0000-4000-8000-000000000004'::UUID,'Singapore','London')
) AS fixture(pseo_page_id, origin_city_id, destination_city_id, origin_name, destination_name);

SELECT public.publish_read_model_version('development_fixture');

UPDATE public.flight_route_options
SET
  departure_time_buckets = CASE
    WHEN operating_airlines[1] IN ('VN', 'JL') THEN ARRAY['morning']::TEXT[]
    WHEN operating_airlines[1] IN ('TG', 'BA') THEN ARRAY['afternoon']::TEXT[]
    WHEN operating_airlines[1] = 'SQ' THEN ARRAY['evening']::TEXT[]
    ELSE ARRAY['early_morning']::TEXT[]
  END,
  cabins = CASE
    WHEN operating_airlines && ARRAY['SQ', 'TG', 'BA', 'JL']::TEXT[]
    THEN ARRAY['economy', 'business']::TEXT[]
    ELSE ARRAY['economy']::TEXT[]
  END
WHERE publication_version_id = (
  SELECT id FROM public.publication_versions WHERE is_current = TRUE
);
