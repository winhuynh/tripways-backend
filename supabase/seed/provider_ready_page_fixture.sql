-- Deterministic non-production fixtures for provider-ready page contracts.
SELECT public.refresh_route_options();

INSERT INTO public.metro_areas(id,country_id,city_id,code,name,slug,source_id,source_record_id,last_verified_at) VALUES
('41000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000004','LON','London airports','london-airports','10000000-0000-4000-8000-000000000001','metro-lon','2026-08-03');
INSERT INTO public.metro_area_airports VALUES('41000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000004',1,now());
INSERT INTO public.place_aliases(id,entity_type,entity_id,locale,alias,normalized_alias,alias_type,source_id,source_record_id,last_verified_at) VALUES
('42000000-0000-4000-8000-000000000001','metro_area','41000000-0000-4000-8000-000000000001','en-GB','LON','lon','code','10000000-0000-4000-8000-000000000001','alias-lon','2026-08-03');

INSERT INTO public.airport_terminals(id,airport_id,code,name,status,source_id,source_record_id,last_verified_at) VALUES
('43000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000003','MAIN','Main Terminal','active','10000000-0000-4000-8000-000000000001','terminal-bkk-main','2026-08-03');
INSERT INTO public.airport_terminal_airlines(terminal_id,airline_id,source_id,last_verified_at) VALUES
('43000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','2026-08-03');
INSERT INTO public.city_facts(id,city_id,locale,fact_type,title,body,structured_value,primary_source_url,last_verified_at,status,data_version) VALUES
('44000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','en-GB','currency','Currency','Thai baht is the local currency.','{"code":"THB"}','https://www.bot.or.th/','2026-08-03','published',(SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1));
INSERT INTO public.airport_facts(id,airport_id,locale,fact_type,title,body,structured_value,primary_source_url,last_verified_at,status,data_version) VALUES
('45000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000003','en-GB','connection','Connections','Allow sufficient transfer time and verify terminal information with the airline.',NULL,'https://www.bangkokairportonline.com/','2026-08-03','published',(SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1));
INSERT INTO public.airport_facilities(id,airport_id,terminal_id,locale,category,name,summary,operating_hours,primary_source_url,last_verified_at,status,display_order,data_version) VALUES
('46000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000003','43000000-0000-4000-8000-000000000001','en-GB','wifi','Airport Wi-Fi','Wi-Fi is available in the terminal.',NULL,'https://www.bangkokairportonline.com/','2026-08-03','published',1,(SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1));

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
  data_version,
  source_freshness_at
)
VALUES (
  '89100000-0000-4000-8000-000000000001',
  'homepage',
  'homepage',
  'en-GB',
  '/',
  'Explore direct flights worldwide',
  'review',
  FALSE,
  'development_fixture',
  (SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1),
  '2026-08-03'
);

INSERT INTO public.homepage_pages (
  id,
  pseo_page_id,
  locale,
  h1,
  subheadline,
  intro,
  seo_title,
  meta_description,
  status,
  is_indexable,
  noindex_reason,
  content_reviewed_at,
  source_freshness_at,
  data_version
)
VALUES (
  '89200000-0000-4000-8000-000000000001',
  '89100000-0000-4000-8000-000000000001',
  'en-GB',
  'Find direct flights from airports worldwide',
  'Choose an origin to compare nonstop destinations, route duration and estimated one-way fares.',
  'Explore stored direct-flight schedules by city or airport. Prices are estimates rather than live availability.',
  'Direct flight routes worldwide | Tripways',
  'Discover direct flights by origin, compare route duration and review estimated one-way fares.',
  'review',
  FALSE,
  'development_fixture',
  '2026-08-03',
  '2026-08-03',
  (SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1)
);

INSERT INTO public.homepage_content_sections (
  homepage_page_id,
  locale,
  section_type,
  heading,
  body,
  display_order,
  status,
  reviewed_at,
  data_version
)
VALUES (
  '89200000-0000-4000-8000-000000000001',
  'en-GB',
  'methodology',
  'How direct routes are shown',
  'Routes are generated from stored schedule data and may change. Confirm operation dates with the airline before booking.',
  1,
  'published',
  '2026-08-03',
  (SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1)
);

INSERT INTO public.homepage_featured_origins (
  homepage_page_id,
  city_id,
  title,
  summary,
  direct_destination_count,
  display_order,
  status,
  reviewed_at,
  data_version
)
VALUES (
  '89200000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000003',
  'Bangkok',
  'Browse direct destinations served from Bangkok airports.',
  4,
  1,
  'published',
  '2026-08-03',
  (SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1)
);

INSERT INTO public.homepage_featured_routes (
  homepage_page_id,
  origin_city_id,
  destination_city_id,
  origin_airport_id,
  destination_airport_id,
  stop_bucket,
  duration_min_minutes,
  duration_max_minutes,
  route_path,
  display_order,
  status,
  reviewed_at,
  data_version
)
VALUES (
  '89200000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000003',
  '30000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000003',
  '40000000-0000-4000-8000-000000000002',
  'direct',
  140,
  180,
  '/flights/bangkok-to-singapore',
  1,
  'published',
  '2026-08-03',
  (SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1)
);

INSERT INTO public.homepage_faqs (
  homepage_page_id,
  locale,
  question,
  answer,
  answer_type,
  display_order,
  status,
  reviewed_at,
  data_version
)
VALUES (
  '89200000-0000-4000-8000-000000000001',
  'en-GB',
  'Are the displayed fares live booking prices?',
  'No. Any displayed fare is an estimated one-way price and should be checked with a booking provider.',
  'hybrid',
  1,
  'published',
  '2026-08-03',
  (SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1)
);

INSERT INTO public.pseo_pages(id,page_type,entity_key,locale,canonical_path,display_title,status,is_indexable,noindex_reason,data_version,source_freshness_at) VALUES
('81200000-0000-4000-8000-000000000001','city_route','ho-chi-minh-city-to-london','en-GB','/flights/ho-chi-minh-city-to-london','Flights from Ho Chi Minh City to London','review',FALSE,'development_fixture',(SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1),'2026-08-03');
INSERT INTO public.route_pages(id,pseo_page_id,origin_city_id,destination_city_id,locale,canonical_slug,h1,subheadline,seo_title,meta_description,intro,direct_option_count,indirect_option_count,fastest_direct_minutes,fastest_indirect_minutes,status,is_indexable,noindex_reason,content_reviewed_at,source_freshness_at,data_version) VALUES
('82200000-0000-4000-8000-000000000001','81200000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004','en-GB','ho-chi-minh-city-to-london','Flights from Ho Chi Minh City to London','Compare direct and connecting flight routes, schedules and estimated price ranges.','Ho Chi Minh City to London flights | Tripways','Explore direct and indirect routes from Ho Chi Minh City to London.','This page compares stored route patterns, not live availability.',1,3,840,900,'review',FALSE,'development_fixture','2026-08-03','2026-08-03',(SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1));
INSERT INTO public.route_page_faqs(route_page_id,question,answer,answer_type,display_order,status,reviewed_at) VALUES
('82200000-0000-4000-8000-000000000001','Are there direct flights?','Stored schedule data includes direct and connecting route patterns.','data_backed',1,'published','2026-08-03');
INSERT INTO public.route_page_airport_comparisons(route_page_id,airport_id,endpoint_role,transfer_summary,duration_min_minutes,duration_max_minutes,primary_source_url,last_verified_at,display_order,status) VALUES
('82200000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','origin','Main international airport serving Ho Chi Minh City.',30,60,'https://www.vietnamairport.vn/','2026-08-03',1,'published'),
('82200000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000004','destination','Heathrow has rail and road links to central London.',30,75,'https://www.heathrow.com/','2026-08-03',2,'published');
INSERT INTO public.route_page_travel_facts(route_page_id,locale,fact_type,title,body,primary_source_url,last_verified_at,status,display_order,data_version) VALUES
('82200000-0000-4000-8000-000000000001','en-GB','timezone','Time difference','Check local time when planning connections.','https://www.gov.uk/when-do-the-clocks-change','2026-08-03','published',1,(SELECT data_version FROM public.route_options ORDER BY generated_at DESC LIMIT 1));
INSERT INTO public.route_page_editorial_sections(route_page_id,locale,section_type,heading,body,display_order,status,reviewed_at) VALUES
('82200000-0000-4000-8000-000000000001','en-GB','direct','Direct routes','Direct patterns minimize connection risk but live operation must be confirmed.',1,'published','2026-08-03'),
('82200000-0000-4000-8000-000000000001','en-GB','disclosure','Data and affiliate disclosure','Schedules and prices are estimates; future approved partner links may be affiliate links.',2,'published','2026-08-03');

SELECT public.publish_read_model_version('development_fixture');
