# City pSEO Page Architecture

## 1. Mục tiêu

Tài liệu này định nghĩa cấu trúc backend, SEO content và UI cần thiết cho một trang pSEO theo
thành phố nguồn, ví dụ:

```text
/flights-from/bangkok
```

Trang đại diện cho toàn bộ thành phố Bangkok và tổng hợp tất cả sân bay phục vụ thành phố, ví dụ:

```text
Bangkok
├── Suvarnabhumi Airport (BKK)
└── Don Mueang International Airport (DMK)
```

Identity chính của trang là **city**, không phải airport. Airport là một dimension để hiển thị và
filter route.

Trang cần đáp ứng đồng thời bốn mục tiêu:

1. Trả lời search intent “direct flights from Bangkok”.
2. Cho phép user khám phá và filter các direct route.
3. Tạo nội dung có giá trị riêng, tránh thin hoặc duplicate pSEO page.
4. Phân phối internal link có cấu trúc tới route, airport, airline, country và related city pages.

Trang tham khảo về content hierarchy và internal linking:
[Wise USD to JPY](https://wise.com/gb/currency-converter/usd-to-jpy-rate).

Wise đặt exact-intent headline và utility ở đầu trang, sau đó mở rộng sang dữ liệu, thống kê, FAQ,
related pairs và change-source links. Tripways áp dụng cùng nguyên tắc cho flight network, không sao
chép nội dung hoặc business logic của Wise.

---

## 2. URL và entity boundaries

### 2.1 Canonical city URL

```text
/flights-from/bangkok
```

Không dùng airport code làm canonical identity của city page:

```text
/flights-from/BKK
```

`BKK` chỉ đại diện cho Suvarnabhumi, không đại diện cho toàn bộ Bangkok.

### 2.2 Các page type liên quan

```text
/flights-from/bangkok
/flights/bangkok-to-tokyo
/flights/bangkok-to-london

/airports/suvarnabhumi-bkk
/airports/don-mueang-dmk

/airlines/thai-airways/from/bangkok
/direct-flights/from/bangkok/to/japan
```

Không bắt buộc build tất cả page type ngay trong phase đầu. Tuy nhiên, taxonomy URL phải được xác
định trước để internal link không phải thay đổi hàng loạt về sau.

### 2.3 Filter URL

Các filter hoạt động bằng query parameter:

```text
/flights-from/bangkok?airport=BKK
/flights-from/bangkok?airline=TG
/flights-from/bangkok?country=JP
/flights-from/bangkok?max_duration=360
```

Các URL filter:

- Không nằm trong sitemap.
- Không tự động trở thành pSEO landing page.
- Canonical về `/flights-from/bangkok`.
- Nên dùng `noindex, follow` nếu route filter có thể được crawl độc lập.

Chỉ tạo landing page riêng cho một filter khi page có search demand, nội dung riêng, dữ liệu đủ mạnh
và đã qua publish review.

---

## 3. Headline và SEO content model

### 3.1 Headline hierarchy

H1 đề xuất:

```text
Direct flights from Bangkok
```

Không thêm `(BKK)` vào H1 vì page bao gồm cả BKK và DMK.

Subheadline đề xuất:

```text
Explore nonstop flights from Bangkok across Suvarnabhumi (BKK) and Don Mueang
(DMK). Compare destinations, airlines, flight times and operating airports.
```

Dynamic introduction đề xuất:

```text
Bangkok has direct flights from 2 airports to 142 destinations across
67 countries. Routes are operated by 48 airlines, with departures from
Suvarnabhumi Airport (BKK) and Don Mueang Airport (DMK).
```

Các con số phải lấy từ read model tại cùng `data_version`, không hardcode trong editorial content.

### 3.2 SEO metadata

Title tag đề xuất:

```text
Direct Flights from Bangkok: Routes & Airlines | Tripways
```

Meta description đề xuất:

```text
Explore direct flights from Bangkok across BKK and DMK. Compare destinations,
airlines, flight duration, operating airports and nonstop routes worldwide.
```

Open Graph:

```text
og:title
Direct flights from Bangkok

og:description
Explore nonstop destinations and airlines from Bangkok's airports.

og:url
https://tripways.com/flights-from/bangkok

og:type
website

og:image
https://tripways.com/og/flights-from/bangkok.png
```

### 3.3 Structured data

Generate structured data từ typed columns:

- `WebPage`
- `BreadcrumbList`
- `ItemList` cho featured direct destinations
- `FAQPage` khi FAQ được render đầy đủ trên page

Không lưu một JSON-LD blob tùy ý làm source of truth. Không dùng `Flight` hoặc `Offer` schema khi page
chưa có dated flight, availability và price thật.

### 3.4 Editorial và generated content

Lưu dưới dạng editorial content:

- H1.
- Subheadline.
- SEO title và description.
- Intro.
- Giải thích hệ thống sân bay.
- FAQ question và answer.
- Optional travel context đã được review.

Generate từ structured data:

- Số sân bay.
- Số direct destinations.
- Số quốc gia.
- Số airlines.
- Shortest và longest route.
- Route cards.
- Airline lists.
- Direct countries.
- Map arcs.
- Structured data.
- Freshness disclosure.

Không ghi số liệu động vào đoạn content tĩnh vì dữ liệu route sẽ thay đổi theo publish version.

---

## 4. Các schema hiện tại được giữ nguyên

Các bảng normalized hiện tại tiếp tục là source of truth:

- `public.countries`
- `public.cities`
- `public.airports`
- `public.airlines`
- `public.flight_routes`
- `public.flight_services`
- `public.route_options`
- `admin.data_sources`

Quan hệ hiện tại đã đủ biểu diễn airport thuộc city:

```text
public.cities.id
        ▲
        │ public.airports.city_id
        │
public.airports
```

Không tạo thêm bảng `city_airports`.

`public.flight_routes` và `public.flight_services` giữ route và recurring schedule truth.
`public.route_options` tiếp tục phục vụ direct/one-stop journey giữa hai airport.

Không sửa `public.rpc_search_routes()` thành city search. Function hiện tại có input:

```text
origin airport IATA → destination airport IATA
```

City page có query shape khác:

```text
origin city → nhiều destination cities
```

---

## 5. Schema mới

## 5.1 `public.pseo_direct_routes`

### Purpose

Read model có thể filter cho tất cả direct route từ một city.

### Grain

Một row đại diện cho:

```text
origin city
+ origin airport
+ destination airport
+ operating airline
+ flight route
```

Ví dụ:

```text
Bangkok + BKK + NRT + TG
Bangkok + BKK + NRT + JL
Bangkok + DMK + NRT + XJ
```

### Columns

| Column                      | Type                | Responsibility                      |
| --------------------------- | ------------------- | ----------------------------------- |
| `id`                        | `UUID`              | Projection row identity             |
| `origin_city_id`            | `UUID`              | City nguồn                          |
| `origin_airport_id`         | `UUID`              | Airport nguồn dùng để filter        |
| `destination_city_id`       | `UUID`              | City đích                           |
| `destination_airport_id`    | `UUID`              | Airport đích                        |
| `destination_country_id`    | `UUID`              | Country đích dùng để filter         |
| `operating_airline_id`      | `UUID`              | Operating airline                   |
| `marketing_airline_id`      | `UUID NULL`         | Marketing airline nếu có            |
| `flight_route_id`           | `UUID`              | Route source reference              |
| `service_count`             | `INTEGER`           | Số recurring services hợp lệ        |
| `frequency_per_week`        | `NUMERIC(6,2) NULL` | Frequency khi nguồn có              |
| `shortest_duration_minutes` | `INTEGER NULL`      | Direct service nhanh nhất           |
| `longest_duration_minutes`  | `INTEGER NULL`      | Direct service dài nhất             |
| `earliest_departure_time`   | `TIME NULL`         | Departure sớm nhất                  |
| `latest_departure_time`     | `TIME NULL`         | Departure muộn nhất                 |
| `seasonality`               | `TEXT`              | `year_round`, `seasonal`, `unknown` |
| `seasonal_start`            | `DATE NULL`         | Seasonal start                      |
| `seasonal_end`              | `DATE NULL`         | Seasonal end                        |
| `confidence_score`          | `NUMERIC(4,3)`      | Publish confidence                  |
| `source_freshness_at`       | `TIMESTAMPTZ`       | Freshness của source                |
| `data_version`              | `UUID`              | Published dataset version           |
| `generated_at`              | `TIMESTAMPTZ`       | Projection generation time          |

### Filter mapping

| UI filter           | Database field              |
| ------------------- | --------------------------- |
| Airport             | `origin_airport_id`         |
| Airline             | `operating_airline_id`      |
| Destination country | `destination_country_id`    |
| Duration            | `shortest_duration_minutes` |
| Departure window    | Departure time fields       |
| Seasonality         | `seasonality`               |

### Indexes

```text
(origin_city_id, destination_city_id)
(origin_city_id, origin_airport_id)
(origin_city_id, operating_airline_id)
(origin_city_id, destination_country_id)
(origin_city_id, shortest_duration_minutes)
```

Không dùng UUID arrays cho các filter chính. Mỗi dimension có foreign key riêng để query và index dễ
hiểu.

## 5.2 `public.city_destination_summaries`

### Purpose

Read model cho destination card mặc định và ranking trước khi user áp dụng filter.

### Grain

Một row:

```text
origin city → destination city
```

Ví dụ:

```text
Bangkok → Tokyo
```

### Columns

| Column                      | Type                | Responsibility               |
| --------------------------- | ------------------- | ---------------------------- |
| `id`                        | `UUID`              | Summary identity             |
| `origin_city_id`            | `UUID`              | City nguồn                   |
| `destination_city_id`       | `UUID`              | City đích                    |
| `destination_country_id`    | `UUID`              | Country đích                 |
| `origin_airport_count`      | `INTEGER`           | Số origin airports có route  |
| `destination_airport_count` | `INTEGER`           | Số destination airports      |
| `airline_count`             | `INTEGER`           | Số operating airlines        |
| `direct_route_count`        | `INTEGER`           | Số route rows                |
| `frequency_per_week`        | `NUMERIC(8,2) NULL` | Aggregate frequency nếu biết |
| `shortest_duration_minutes` | `INTEGER NULL`      | Duration nhanh nhất          |
| `longest_duration_minutes`  | `INTEGER NULL`      | Duration dài nhất            |
| `distance_km`               | `INTEGER NULL`      | Khoảng cách đại diện         |
| `seasonality`               | `TEXT`              | Aggregate seasonality        |
| `confidence_score`          | `NUMERIC(4,3)`      | Confidence an toàn           |
| `ranking_score`             | `NUMERIC`           | Stable database ranking      |
| `source_freshness_at`       | `TIMESTAMPTZ`       | Freshness                    |
| `data_version`              | `UUID`              | Dataset version              |
| `generated_at`              | `TIMESTAMPTZ`       | Generation time              |

Unique identity:

```text
(origin_city_id, destination_city_id, data_version)
```

Khi user áp dụng filter, RPC query `pseo_direct_routes` và aggregate theo destination city. Không
filter trên một summary array đã mất grain.

## 5.3 `public.city_pages`

### Purpose

Lưu content, metadata và publish state cho một city page theo locale.

### Columns

| Column                             | Type               | Responsibility                             |
| ---------------------------------- | ------------------ | ------------------------------------------ |
| `id`                               | `UUID`             | Page identity                              |
| `pseo_page_id`                     | `UUID`             | Global pSEO registry reference             |
| `city_id`                          | `UUID`             | City owner                                 |
| `locale`                           | `TEXT`             | Ví dụ `en-GB`                              |
| `canonical_slug`                   | `TEXT`             | Ví dụ `bangkok`                            |
| `h1`                               | `TEXT`             | Page headline                              |
| `subheadline`                      | `TEXT`             | Utility explanation                        |
| `seo_title`                        | `TEXT`             | HTML title                                 |
| `meta_description`                 | `TEXT`             | Search result description                  |
| `og_title`                         | `TEXT`             | Social title                               |
| `og_description`                   | `TEXT`             | Social description                         |
| `og_image_path`                    | `TEXT NULL`        | Generated image path                       |
| `intro`                            | `TEXT`             | Editorial introduction                     |
| `airport_summary`                  | `TEXT NULL`        | Editorial airport-system content           |
| `status`                           | `TEXT`             | `draft`, `review`, `published`, `archived` |
| `is_indexable`                     | `BOOLEAN`          | Final database-owned indexability          |
| `noindex_reason`                   | `TEXT NULL`        | Stable reason when excluded                |
| `primary_airport_id`               | `UUID NULL`        | Airport đại diện cho visual only           |
| `airport_count`                    | `INTEGER`          | Generated quick fact                       |
| `direct_counterpart_city_count`    | `INTEGER`          | Generated quick fact                       |
| `direct_counterpart_country_count` | `INTEGER`          | Generated quick fact                       |
| `airline_count`                    | `INTEGER`          | Generated quick fact                       |
| `shortest_route_minutes`           | `INTEGER NULL`     | Generated quick fact                       |
| `longest_route_minutes`            | `INTEGER NULL`     | Generated quick fact                       |
| `content_reviewed_at`              | `TIMESTAMPTZ NULL` | Editorial review time                      |
| `source_freshness_at`              | `TIMESTAMPTZ`      | Data freshness                             |
| `data_version`                     | `UUID`             | Published dataset version                  |
| `generated_at`                     | `TIMESTAMPTZ`      | Read model generation time                 |
| `published_at`                     | `TIMESTAMPTZ NULL` | Page publication time                      |
| `created_at`                       | `TIMESTAMPTZ`      | Audit                                      |
| `updated_at`                       | `TIMESTAMPTZ`      | Audit                                      |

Unique identity:

```text
(city_id, locale)
```

Không đặt SEO content trực tiếp vào `public.cities`. Geographic identity và pSEO publication có
lifecycle khác nhau.

## 5.4 `public.city_page_faqs`

| Column          | Type               | Responsibility                       |
| --------------- | ------------------ | ------------------------------------ |
| `id`            | `UUID`             | FAQ identity                         |
| `city_page_id`  | `UUID`             | Page owner                           |
| `question`      | `TEXT`             | User-facing question                 |
| `answer`        | `TEXT`             | Reviewed answer                      |
| `answer_type`   | `TEXT`             | `editorial`, `data_backed`, `hybrid` |
| `display_order` | `SMALLINT`         | Stable ordering                      |
| `status`        | `TEXT`             | `draft`, `review`, `published`       |
| `reviewed_at`   | `TIMESTAMPTZ NULL` | Review time                          |
| `created_at`    | `TIMESTAMPTZ`      | Audit                                |
| `updated_at`    | `TIMESTAMPTZ`      | Audit                                |

FAQ gợi ý:

- How many direct destinations can you fly to from Bangkok?
- Which airports serve direct flights from Bangkok?
- Which airlines fly direct from Bangkok?
- Can I filter Bangkok flights by departure airport?
- What is the shortest direct flight from Bangkok?
- What is the longest direct flight from Bangkok?

Các answer có số liệu phải dùng cùng `data_version` với page.

## 5.5 `public.pseo_pages`

### Purpose

Global registry cho canonical URL, sitemap, publish state và internal-link targets.

### Columns

| Column                | Type          | Responsibility                                                            |
| --------------------- | ------------- | ------------------------------------------------------------------------- |
| `id`                  | `UUID`        | Global page identity                                                      |
| `page_type`           | `TEXT`        | `city`, `airport`, `city_route`, `airline_city`, `country_route`, `guide` |
| `entity_key`          | `TEXT`        | Stable normalized identity                                                |
| `locale`              | `TEXT`        | Page locale                                                               |
| `canonical_path`      | `TEXT`        | Canonical URL path                                                        |
| `display_title`       | `TEXT`        | Internal navigation title                                                 |
| `status`              | `TEXT`        | `draft`, `review`, `published`, `archived`                                |
| `is_indexable`        | `BOOLEAN`     | Sitemap/indexability state                                                |
| `noindex_reason`      | `TEXT NULL`   | Exclusion reason                                                          |
| `data_version`        | `UUID`        | Dataset version                                                           |
| `content_updated_at`  | `TIMESTAMPTZ` | Content freshness                                                         |
| `source_freshness_at` | `TIMESTAMPTZ` | Source freshness                                                          |
| `generated_at`        | `TIMESTAMPTZ` | Generation time                                                           |

Sitemap đọc từ bảng này, không chạy graph aggregation khi sitemap được request.

## 5.6 `public.pseo_internal_links`

### Purpose

Precomputed semantic link graph giữa các indexable pages.

### Columns

| Column            | Type          | Responsibility           |
| ----------------- | ------------- | ------------------------ |
| `source_page_id`  | `UUID`        | Page đang render link    |
| `target_page_id`  | `UUID`        | Published target page    |
| `link_cluster`    | `TEXT`        | Semantic module          |
| `anchor_text`     | `TEXT`        | Contextual anchor        |
| `secondary_text`  | `TEXT NULL`   | Optional supporting text |
| `display_zone`    | `TEXT`        | UI placement             |
| `relevance_score` | `NUMERIC`     | Ranking                  |
| `display_order`   | `SMALLINT`    | Stable ordering          |
| `is_featured`     | `BOOLEAN`     | Featured state           |
| `data_version`    | `UUID`        | Version                  |
| `generated_at`    | `TIMESTAMPTZ` | Generation time          |

Unique identity:

```text
(source_page_id, target_page_id, link_cluster)
```

Link chỉ được generate khi target:

```text
is published
AND is indexable
AND has useful route data
AND has SEO-approved source rights
AND passes freshness threshold
AND passes confidence threshold
```

---

## 6. Internal-link taxonomy

Internal link không được tạo bằng cách dump toàn bộ database lên page. Link phải chia thành semantic
clusters giống cách Wise chia currency pair, source currency, popular amounts và related tools.

### 6.1 Popular direct routes

```text
Bangkok to Tokyo flights
Bangkok to Singapore flights
Bangkok to London flights
Bangkok to Seoul flights
Bangkok to Dubai flights
```

### 6.2 Airports in Bangkok

```text
Flights from Suvarnabhumi Airport
Flights from Don Mueang Airport
Airlines at Suvarnabhumi Airport
Direct routes from Don Mueang Airport
```

### 6.3 Airlines from Bangkok

```text
Thai Airways flights from Bangkok
AirAsia flights from Bangkok
Emirates flights from Bangkok
Singapore Airlines flights from Bangkok
```

### 6.4 Direct countries

```text
Direct flights from Bangkok to Japan
Direct flights from Bangkok to Singapore
Direct flights from Bangkok to the United Kingdom
Direct flights from Bangkok to Australia
```

### 6.5 Change source city

Tương đương module “Change source currency” của Wise:

```text
Direct flights from Chiang Mai
Direct flights from Phuket
Direct flights from Krabi
Direct flights from Koh Samui
```

### 6.6 Reverse intent

```text
Direct flights to Bangkok
Tokyo to Bangkok flights
Singapore to Bangkok flights
London to Bangkok flights
```

### 6.7 Guides và supporting content

```text
Bangkok airports guide
BKK vs DMK: which Bangkok airport should you use?
How to find direct flights from Bangkok
International airlines flying from Bangkok
```

Guide chỉ được publish khi có nội dung hữu ích và được review, không generate thin pages hàng loạt.

### 6.8 Internal-link quality rules

- Chỉ link tới page đã published và indexable.
- Anchor mô tả chính xác target.
- Không lặp cùng target ở quá nhiều modules.
- Không tạo hàng trăm anchor chỉ thay một keyword.
- Render link server-side trong HTML.
- “Show more” phải giữ các target quan trọng crawlable.
- Query-parameter filter không trở thành SEO link.
- Link ranking phải ổn định trong cùng `data_version`.

Số link gợi ý cho phase đầu:

| Module                | Suggested range |
| --------------------- | --------------: |
| Featured destinations |            6–12 |
| Popular routes        |            8–16 |
| Airports              |             2–5 |
| Airlines              |            6–12 |
| Direct countries      |            8–16 |
| Change source city    |            6–12 |
| Reverse routes        |             4–8 |
| Related guides        |             4–8 |

Đây là information-hierarchy guideline, không phải SEO quota cố định.

---

## 7. RPC contracts

## 7.1 `public.rpc_get_city_page(p_input JSONB)`

### Responsibility

Trả page shell, metadata, initial cards và internal-link modules trong một bounded payload.

### Input

```json
{
  "city_slug": "bangkok",
  "locale": "en-GB",
  "destination_limit": 8
}
```

### Output

```json
{
  "data": {
    "city": {},
    "country": {},
    "page": {},
    "airports": [],
    "quick_facts": {},
    "featured_destinations": [],
    "featured_airlines": [],
    "direct_countries": [],
    "faqs": [],
    "internal_link_groups": []
  },
  "meta": {
    "canonical_path": "/flights-from/bangkok",
    "is_indexable": true,
    "data_version": "uuid",
    "generated_at": "timestamp",
    "source_freshness_at": "timestamp"
  },
  "error": null
}
```

RPC không trả toàn bộ destination list. Initial payload cần bounded để giữ response nhỏ và cacheable.

## 7.2 `public.rpc_search_city_direct_routes(p_input JSONB)`

### Responsibility

Filter, aggregate, facet, rank và paginate direct destinations từ một city.

### Input

```json
{
  "city_slug": "bangkok",
  "origin_airports": ["BKK"],
  "airlines": ["TG"],
  "destination_countries": ["JP"],
  "max_duration_minutes": 600,
  "departure_window": "morning",
  "seasonality": "year_round",
  "limit": 20,
  "offset": 0
}
```

### Output

```json
{
  "data": [],
  "meta": {
    "total": 42,
    "limit": 20,
    "offset": 0,
    "facets": {
      "airports": [],
      "airlines": [],
      "countries": [],
      "duration_bands": []
    }
  },
  "error": null
}
```

Facets và result list phải được tính từ cùng filtered set để UI không hiển thị count mâu thuẫn.

---

## 8. Publish và indexability

Một city page chỉ được index khi:

```text
page status is published
AND page has useful direct-route data
AND at least one source allows production use
AND all displayed source data allows SEO use
AND page is not built from development fixture
AND route confidence passes threshold
AND source freshness passes threshold
AND content has passed editorial review
```

`admin.data_sources` tiếp tục sở hữu:

- `environment_scope`
- `production_allowed`
- `seo_allowed`
- `derived_data_allowed`

Development fixture hiện tại có `seo_allowed = FALSE`, vì vậy chỉ được dùng để test local. Fixture
page không được vào production sitemap.

Sau một publish thành công:

```text
publish normalized route data
→ rebuild city_direct_routes
→ rebuild city_destination_summaries
→ update city_pages counters and freshness
→ rebuild pseo_pages indexability
→ rebuild pseo_internal_links
→ publish one new data_version
```

Toàn bộ flow cần transaction hoặc rollback-safe publish boundary để page không đọc dữ liệu từ hai
versions khác nhau.

---

## 9. Đề xuất thay đổi UI

## 9.1 Hero

### Hiện trạng cần sửa

- Headline đang giống airport page và gắn BKK với Bangkok.
- “Direct flights from Bangkok (BKK)” khiến user hiểu rằng Bangkok chỉ có một sân bay.
- Airport identity đang lấn át city identity.

### Đề xuất

```text
H1: Direct flights from Bangkok

Subheadline:
Explore nonstop routes from Bangkok across Suvarnabhumi (BKK) and Don Mueang
(DMK). Compare destinations, airlines and flight times.
```

Ngay dưới intro hiển thị dynamic proof:

```text
2 airports · 142 direct destinations · 67 countries · 48 airlines
```

Thêm “Data updated” và freshness tooltip gần quick facts, không đặt ở cuối page.

## 9.2 Search utility

Giữ destination search ngay đầu page, vì đây là tương đương flight utility của currency converter
trên Wise.

Search box:

```text
Where do you want to fly from Bangkok?
```

Không dùng placeholder “Search routes from BKK”.

Khi user chọn destination:

```text
/flights/bangkok-to-tokyo
```

City-to-city URL là default. Airport pair được chọn ở bước filter hoặc live-search flow sau.

## 9.3 Map

Map phải vẽ route từ cả BKK và DMK nhưng tránh tạo hai đường gần như trùng nhau cho mọi destination.

Default map:

- Group origin markers thành Bangkok airport cluster.
- Một arc đại diện cho một destination city.
- Click destination mở card hoặc route page.
- Airport filter thay đổi origin marker và visible arcs.

Map cần có legend:

```text
Bangkok airports
Direct destinations
Stored route data — not live tracking
```

## 9.4 Filter toolbar

Thứ tự filter đề xuất:

1. Departure airport.
2. Airline.
3. Destination country or region.
4. Flight duration.
5. Departure time.
6. Seasonality.

Không cần “Direct only” toggle trên page này vì toàn bộ dataset đã là direct routes. Thay bằng một
label trạng thái:

```text
Nonstop routes only
```

Airport filter:

```text
All Bangkok airports
Suvarnabhumi (BKK)
Don Mueang (DMK)
```

Toolbar cần:

- Selected-filter chips.
- Clear-all action.
- Updated result count.
- Mobile filter drawer.
- URL-backed state để user share filter.

## 9.5 Destination cards

Card identity là destination city, không phải một airport đích.

Ví dụ:

```text
Tokyo
Japan · Narita (NRT), Haneda (HND)
```

Card cần hiển thị:

- Origin airports: `From BKK and DMK`.
- Destination airports.
- Shortest direct duration.
- Airlines.
- Frequency nếu biết.
- Seasonality hoặc “Schedule varies”.
- Link tới `/flights/bangkok-to-tokyo`.

Không ghi “best time” nếu backend chưa có nguồn travel-season data đáng tin cậy.

## 9.6 Quick facts

Sidebar desktop hoặc horizontal cards trên mobile:

- Bangkok airports.
- Direct destinations.
- Countries.
- Airlines.
- Shortest route.
- Longest route.
- Most frequent destination nếu frequency đủ tin cậy.

Mọi fact cần tooltip hoặc linked explanation khi metric không hiển nhiên.

## 9.7 Airport section

Thêm section riêng:

```text
Airports with direct flights from Bangkok
```

Mỗi airport card:

- Name và code.
- Số direct destinations.
- Số airlines.
- International/domestic route split nếu dữ liệu đủ.
- Link tới airport page.
- “Use this airport” filter action.

Section này làm rõ city page tổng hợp nhiều airport và tạo internal link tự nhiên.

## 9.8 Airline section

Thay sidebar list ngắn bằng module có giá trị:

```text
Airlines flying direct from Bangkok
```

Mỗi airline:

- Name và code.
- Số direct destinations.
- Airports hãng đang khai thác tại Bangkok.
- Top destinations.
- Link tới airline-city page khi target indexable.

Không render “View all airlines” tới một trang rỗng hoặc chưa indexable.

## 9.9 Internal-link modules

Tổ chức thành các section có heading, không gom thành một link cloud:

```text
Popular direct routes from Bangkok
Countries you can fly to directly
Airports in Bangkok
Airlines flying from Bangkok
Change your departure city
Flights to Bangkok
Bangkok flight guides
```

Mỗi module chỉ nhận link từ `pseo_internal_links`.

## 9.10 FAQ và trust

FAQ nằm sau utility/data content, trước related links cuối trang.

Thêm data disclosure:

```text
Route information is based on published recurring schedules and is not live
availability. Schedules can change. Last verified: [date].
```

Không dùng copy như “live flight data” nếu backend chỉ có stored recurring route data.

## 9.11 Mobile layout

Mobile order đề xuất:

```text
Headline
Quick facts
Destination search
Airport selector
Map
Filter button
Result count
Destination cards
Airport section
Airline section
Internal-link modules
FAQ
Freshness disclosure
```

Quick facts không nên bị đưa vào sidebar bên dưới hàng chục cards. Airport filter phải xuất hiện sớm
vì đây là khác biệt cốt lõi của city page.

---

## 10. Recommended page structure

```text
Breadcrumb

H1: Direct flights from Bangkok
Subheadline
Dynamic quick facts
Freshness disclosure

Destination search
Airport selector

Interactive direct-route map
Filter toolbar

Featured direct destinations
All direct destinations

Airports with direct flights from Bangkok
Airlines flying direct from Bangkok
Countries you can fly to directly

Popular routes from Bangkok
Change departure city
Flights to Bangkok

Bangkok airport guide
Related flight guides
FAQ

Related pages
Data methodology and freshness
```

---

## 11. Implementation phases

### Phase 1 — City page foundation

Build:

1. `public.pseo_direct_routes`
2. `public.city_destination_summaries`
3. `public.city_pages`
4. `public.city_page_faqs`
5. `public.pseo_pages`
6. `public.pseo_internal_links`
7. `public.rpc_get_city_page()`
8. `public.rpc_search_city_direct_routes()`
9. Rebuild function cho city read models

UI:

- City-first headline.
- Bangkok airport selector.
- City destination cards.
- Basic filters.
- Quick facts.
- Initial internal-link groups.

### Phase 2 — Route pages và link graph

Build:

- City-to-city route pages.
- Reverse routes.
- Airline-city pages.
- Country-route landing pages có demand.
- Sitemap generation.
- Internal-link ranking.

### Phase 3 — Editorial depth

Build:

- Airport guides.
- BKK versus DMK guide.
- Reviewed travel insights.
- Locale-specific content.
- Content QA and review workflow.

### Deferred

Không build trong foundation:

- Live price.
- Dated availability.
- Booking offers.
- AI-generated content publishing tự động.
- Collections như beaches hoặc digital nomad khi chưa có taxonomy và source.
- Redis.
- Personalized ranking.
- Indexable filter combinations.

---

## 12. Definition of Done

City pSEO foundation hoàn thành khi:

- Bangkok page tổng hợp đúng tất cả active airports thuộc city.
- Airport và airline filters trả facets nhất quán.
- Destination cards aggregate theo destination city.
- Canonical URL không phụ thuộc airport code.
- Filter URLs không vào sitemap.
- Metadata, H1 và intro phản ánh đúng city intent.
- Internal links chỉ trỏ tới published, indexable targets.
- Sitemap đọc precomputed page registry.
- Page counters và route data sử dụng cùng `data_version`.
- Development fixture không thể trở thành indexable.
- RPC trả shared `{ data, meta, error }` envelope.
- Desktop và mobile UI làm rõ city-to-airport relationship.
