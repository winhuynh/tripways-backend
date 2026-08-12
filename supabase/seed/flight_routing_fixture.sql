-- Minimal provider-neutral fixture for local route and pSEO testing.
INSERT INTO admin.data_sources (id,code,name,source_type,environment_scope,license_notes)
VALUES ('10000000-0000-4000-8000-000000000001','route_discovery_fixture','Route Discovery Development Fixture','development_fixture','development','Synthetic local-only evidence.');

INSERT INTO public.countries (id,iso2,iso3,name,slug,region,subregion,source_id,source_record_id) VALUES
('20000000-0000-4000-8000-000000000001','VN','VNM','Vietnam','vietnam','Asia','South-Eastern Asia','10000000-0000-4000-8000-000000000001','country-vn'),
('20000000-0000-4000-8000-000000000002','SG','SGP','Singapore','singapore','Asia','South-Eastern Asia','10000000-0000-4000-8000-000000000001','country-sg'),
('20000000-0000-4000-8000-000000000004','GB','GBR','United Kingdom','united-kingdom','Europe','Northern Europe','10000000-0000-4000-8000-000000000001','country-gb');

INSERT INTO public.cities (id,country_id,name,slug,iata_code,currency_code,primary_language,latitude,longitude,timezone,source_id,source_record_id) VALUES
('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Ho Chi Minh City','ho-chi-minh-city','SGN','VND','vi',10.8231,106.6297,'Asia/Ho_Chi_Minh','10000000-0000-4000-8000-000000000001','city-sgn'),
('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','Singapore','singapore','SIN','SGD','en',1.3521,103.8198,'Asia/Singapore','10000000-0000-4000-8000-000000000001','city-sin'),
('30000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000004','London','london','LON','GBP','en',51.5072,-0.1276,'Europe/London','10000000-0000-4000-8000-000000000001','city-lon');

INSERT INTO public.airports (id,iata,icao,name,slug,city_id,country_id,latitude,longitude,timezone,airport_type,status,source_id,source_record_id,last_verified_at) VALUES
('40000000-0000-4000-8000-000000000001','SGN','VVTS','Tan Son Nhat International Airport','tan-son-nhat-international-airport','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',10.8188,106.6520,'Asia/Ho_Chi_Minh','large_airport','active','10000000-0000-4000-8000-000000000001','airport-sgn',now()),
('40000000-0000-4000-8000-000000000002','SIN','WSSS','Singapore Changi Airport','singapore-changi-airport','30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002',1.3644,103.9915,'Asia/Singapore','large_airport','active','10000000-0000-4000-8000-000000000001','airport-sin',now()),
('40000000-0000-4000-8000-000000000004','LHR','EGLL','Heathrow Airport','heathrow-airport','30000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000004',51.4700,-0.4543,'Europe/London','large_airport','active','10000000-0000-4000-8000-000000000001','airport-lhr',now());

INSERT INTO public.airlines (id,iata,icao,name,slug,country_id,business_model,status,source_id,source_record_id,last_verified_at) VALUES
('50000000-0000-4000-8000-000000000001','VN','HVN','Vietnam Airlines','vietnam-airlines','20000000-0000-4000-8000-000000000001','full_service','active','10000000-0000-4000-8000-000000000001','airline-vn',now()),
('50000000-0000-4000-8000-000000000002','SQ','SIA','Singapore Airlines','singapore-airlines','20000000-0000-4000-8000-000000000002','full_service','active','10000000-0000-4000-8000-000000000001','airline-sq',now());

INSERT INTO public.flight_routes (id,origin_airport_id,destination_airport_id,canonical_airline_id,provider_airline_iata,evidence_type,status,confidence_score,source_id,source_record_id,observed_at) VALUES
('60000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000004','50000000-0000-4000-8000-000000000001','VN','manual','verified_active',0.980,'10000000-0000-4000-8000-000000000001','route-sgn-lhr',now()),
('60000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000002','SQ','manual','verified_active',0.990,'10000000-0000-4000-8000-000000000001','route-sgn-sin',now());

INSERT INTO public.pseo_pages (id,page_type,entity_key,locale,canonical_path,display_title,status,is_indexable,noindex_reason,source_freshness_at) VALUES
('81000000-0000-4000-8000-000000000001','city','ho-chi-minh-city','en-GB','/flights-from-ho-chi-minh-city','Flights from Ho Chi Minh City','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000002','airport','sgn','en-GB','/airports/sgn','Tan Son Nhat Airport guide','published',false,'development_fixture',now()),
('81000000-0000-4000-8000-000000000003','city_route','ho-chi-minh-city-london','en-GB','/flights/ho-chi-minh-city-london','Ho Chi Minh City to London flights','published',false,'development_fixture',now());

INSERT INTO public.city_pages (pseo_page_id,city_id,locale,route_direction,primary_airport_id,content,content_reviewed_at) VALUES
('81000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','en-GB','outbound','40000000-0000-4000-8000-000000000001','{"seo":{"h1":"Flights from Ho Chi Minh City"},"intro":"Explore route evidence and cached observations."}',now());
INSERT INTO public.airport_pages (pseo_page_id,airport_id,locale,content,content_reviewed_at) VALUES
('81000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000001','en-GB','{"seo":{"h1":"Tan Son Nhat Airport guide"},"orientation":"Local development fixture."}',now());
INSERT INTO public.route_pages (pseo_page_id,origin_city_id,destination_city_id,locale,content,content_reviewed_at) VALUES
('81000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004','en-GB','{"seo":{"h1":"Ho Chi Minh City to London flights"},"intro":"Compare cached route observations before partner handoff."}',now());

SELECT public.publish_read_model_version('development_fixture');
