# Canonical pSEO Backend Contract Design

**Ngày:** 2026-08-05  
**Trạng thái:** Chờ chủ sở hữu review  
**Phạm vi:** Backend contract cho Homepage, City Hub, Airport Hub và Route Page

## 1. Mục tiêu

Backend là nguồn sự thật duy nhất cho:

- aviation facts;
- SEO title, meta description, H1, subheadline và intro;
- page-specific editorial content;
- facts, summaries, FAQs và internal links;
- direct và connecting route results;
- estimated fare có source, confidence và expiry;
- provenance, freshness, publication và indexability.

Frontend tiếp tục sở hữu header, footer, navigation, button labels, filter labels, Terms và technical
fallback copy. Các phần này không thuộc contract trong tài liệu này.

## 2. Nguồn yêu cầu nội dung

Thiết kế đối chiếu bốn frame trong file Figma `tripways`:

- `Homepage — Route Discovery — Desktop — Display Ads`;
- `City Hub — Bangkok — Sidebar Discovery — Final Fixed`;
- `Airport Hub — BKK — Route Discovery + Departure Guide — Final Extended`;
- `Route — Bangkok to London — City Hub Pattern — All Flight Options`.

Các spec City Hub, Airport Hub, Route Page và advertising trong `tripways-web/docs/superpowers/specs`
được dùng để kiểm tra chi tiết module đã thống nhất khi layer Figma chỉ thể hiện presentation.

## 3. Các phương án đã xem xét

### 3.1 Typed page schemas — được chọn

Core aviation facts được chuẩn hoá dùng chung; content và FAQ nằm trong schema riêng của từng page.
PostgreSQL constraints kiểm soát type, publication status, source và freshness.

### 3.2 Generic JSONB page modules — không chọn

Linh hoạt nhưng làm yếu validation, queryability và publication gate. Không phù hợp mục tiêu sinh
hàng triệu page có contract ổn định.

### 3.3 Vá các RPC hiện tại — không chọn

Nhanh nhưng giữ split RPC, hậu tố `_v2`, duplicate composer và legacy response shape.

## 4. Kiến trúc mục tiêu

### 4.1 Core aviation

Các bảng canonical dùng chung:

- `countries`, `cities`, `metro_areas`, `metro_area_airports`;
- `airports`, `airport_terminals`, `airport_terminal_airlines`, `nearby_airports`;
- `airlines`;
- `flight_routes`, `flight_services`, `route_options`;
- `route_price_estimates`;
- `data_sources`, ingestion tables và `publication_versions`.

Core aviation không chứa page heading, editorial paragraph hoặc layout-specific field.

### 4.2 Page registry và publication

`pseo_pages` giữ identity chung, canonical path, page type và publication eligibility.

Mỗi page type có typed root table riêng:

- `homepage_pages`;
- `city_pages`;
- `airport_pages`;
- `route_pages`.

Mỗi publication version materialize payload bất biến vào read-model table tương ứng. Public request
chỉ đọc current published version; không compose payload từ nhiều bảng trong request path.

## 5. Schema theo page

### 5.1 Homepage

#### `homepage_pages`

- `id`, `pseo_page_id`, `locale`;
- `h1`, `subheadline`, `intro`;
- `seo_title`, `meta_description`;
- `status`, `is_indexable`, `noindex_reason`;
- `content_reviewed_at`, `source_freshness_at`, `data_version`;
- timestamps.

#### `homepage_featured_origins`

- origin city/airport identity;
- title, summary, image metadata nếu được cấp quyền;
- direct destination count;
- display order, status và data version.

#### `homepage_featured_routes`

- origin/destination city và optional airport pair;
- direct/stop bucket;
- duration range, operating airlines và estimated one-way fare reference;
- route path, display order và publication fields.

#### `homepage_content_sections`

- `section_type` giới hạn vào `discovery_intro`, `methodology`, `data_disclaimer`, `directory_intro`;
- `heading`, `body`, `display_order`;
- source/review/version fields.

#### `homepage_faqs`

- question, answer, answer type, display order;
- source/review/version fields.

Homepage map và discovery result lấy từ route projection, không lưu bản sao route graph trong content
tables.

### 5.2 City Hub

#### `city_pages`

Giữ typed SEO/editorial root và `route_direction`. City Hub production dùng outbound/direct-first.

#### `city_page_airport_content`

- airport identity;
- airport-specific summary trong ngữ cảnh thành phố;
- route count/fact overrides chỉ khi đã review;
- source, freshness và display order.

#### `city_destination_summaries`

- destination city/airport/country/region;
- departure airport set;
- minimum/maximum duration;
- frequency summary và seasonality state;
- estimated one-way fare state/range/currency/expiry;
- direct route path, confidence và display order.

Derived route facts được materialize từ canonical graph; editorial summary chỉ nằm tại bảng này khi
cần copy đã review.

#### `city_facts`

- typed fact key/value/unit;
- source, freshness, display order và status.

#### `city_content_sections`

- `section_type` giới hạn vào `route_context`, `airport_context`, `travel_context`, `methodology`,
  `data_disclaimer`;
- heading/body, source/review/version fields.

Không có standalone airline editorial section. Airline chỉ xuất hiện trong route result và facet.

#### `city_page_faqs`

FAQ riêng theo city page, locale và data version.

### 5.3 Airport Hub

#### `airport_pages`

Root SEO/editorial và publication fields cho một airport/locale.

#### `airport_facts`

- terminal count, timezone, location, city/region/country, operational facts;
- typed value/unit, source/freshness và display order.

#### `airport_access_options`

- access type, service name, destination/coverage;
- duration range, price range/currency;
- operating hours, booking URL khi được phép;
- source, verification và status.

#### `airport_parking_information`

- availability, parking type, location/summary;
- duration/rate fields nếu source cho phép;
- booking/official URLs, source, freshness và status.

#### `airport_lounges`

- lounge name, terminal/location;
- access type, eligible programs/airlines;
- amenities, hours và booking URL nếu được phép;
- source, freshness và status.

#### `airport_facilities`

- facility type, name, location, availability/summary;
- source, freshness, order và status.

#### `airport_page_notices`

- notice type, severity, title/body;
- effective dates, source, last verified và status.

#### `airport_content_sections`

- `section_type` giới hạn vào `departure_guide`, `route_context`, `access_intro`, `parking_intro`,
  `lounge_intro`, `facilities_intro`, `methodology`, `data_disclaimer`;
- heading/body và source/review/version fields.

#### `airport_page_faqs`

FAQ riêng theo airport page, locale và data version.

Route explorer dùng shared route projection với scope `origin_airport`, mặc định direct-only.

### 5.4 Route Page

#### `route_pages`

- origin/destination city;
- canonical slug và locale;
- H1, subheadline, intro, SEO fields;
- direct/indirect counts và fastest duration facts;
- publication, freshness và indexability fields.

#### `route_page_airport_comparisons`

- endpoint role;
- airport identity;
- transfer summary, duration range và price range;
- source, freshness, display order và status.

#### `route_page_travel_facts`

- timezone, entry/transit guidance, currency, language, arrival transport và travel tip;
- title/body/structured value;
- required primary source, verification và version.

#### `route_page_editorial_sections`

- direct, indirect, schedule, before-you-fly, alternatives, methodology và disclosure;
- heading/body/order/review status.

#### `route_page_faqs`

FAQ riêng theo directional city pair, locale và data version.

Route options lấy từ shared route projection với scope `city_pair`, hỗ trợ direct đến ba điểm dừng.

## 6. Route-search projection

Chỉ giữ một materialized projection: `route_search_options`.

Projection phải chứa:

- origin/destination city, airport, country và region identity;
- domestic/international flag;
- stop count và connection airports;
- operating/marketing airlines;
- departure/arrival local time, days of week và validity window;
- flight, layover, maximum layover và total duration;
- route path và confidence;
- estimated fare state, one-way range, currency và expiry;
- publication version.

Supported scopes:

- `global`;
- `origin_city`;
- `origin_airport`;
- `city_pair`.

Supported filters:

- maximum stops;
- departure airport;
- destination country/region;
- domestic/international;
- airline;
- connection airport;
- maximum duration/layover;
- departure-time bucket;
- cabin;
- maximum estimated one-way price và currency.

Pagination dùng deterministic keyset. Facet counts được tính sau khi áp dụng scope và các filter còn
lại theo semantics đã document; missing price không được xem là zero.

## 7. Public RPC contract

### 7.1 `rpc_get_page`

Input:

```json
{
  "page_type": "homepage|city|airport|route",
  "identity": {},
  "locale": "en-GB"
}
```

Output:

```json
{
  "data": {
    "page": {},
    "seo": {},
    "facts": {},
    "discovery": {},
    "content": {},
    "faqs": [],
    "internal_links": []
  },
  "meta": {
    "data_version": "uuid",
    "freshness": {},
    "provenance": {},
    "indexability": {}
  },
  "error": null
}
```

RPC chỉ đọc page-specific read model thuộc current publication version.

### 7.2 `rpc_search_routes`

Nhận scope, filters, page size và cursor. Đây là public route-discovery contract duy nhất.

### 7.3 Public RPC khác được giữ

- `rpc_search_places` vì đây là place autocomplete capability riêng;
- `rpc_get_sitemap`;
- ingestion/publication RPC có trách nhiệm khác biệt;
- health và user functions ngoài phạm vi pSEO.

## 8. Duplicate và legacy removal

Xoá sau khi test canonical contract chạy xanh:

- `rpc_get_page_v2`;
- `rpc_search_route_options_v2`;
- `rpc_search_route_options`;
- `rpc_get_homepage_discovery`;
- `rpc_get_city_page`, `rpc_get_airport_page`, `rpc_get_route_page`;
- các split city RPC: overview, airports, airlines, FAQs, insights, internal links, quick facts và map;
- `refresh_city_pseo_read_models` nếu publication pipeline chung đã bao phủ;

`route_options` được giữ làm canonical computed graph source cho publication build;
`route_search_options` là immutable published search projection. Hai bảng có trách nhiệm khác nhau
và không được chứa hai implementation ranking độc lập.

Private helpers chỉ được giữ khi có một trách nhiệm rõ và được composer/publication pipeline dùng.
Không đổi tên legacy rồi để lại logic trùng lặp.

Trước khi xoá mỗi object phải chạy dependency audit trên SQL source, Edge handlers, snippets, tests
và generated migration.

## 9. Data flow

1. Provider adapter ghi raw records vào private ingestion schema.
2. Validation chuẩn hoá entities và route/schedule facts.
3. Publication candidate tạo core graph, route projection và page content snapshots.
4. Completeness, rights, freshness và indexability gates chạy trước promote.
5. Candidate hợp lệ được promote atomically thành current publication.
6. `rpc_get_page` đọc immutable page snapshot.
7. `rpc_search_routes` đọc immutable route projection cùng publication version.
8. Frontend không gọi provider và không join content ở client.

## 10. Error và unknown handling

- Mọi public RPC dùng shared `data/meta/error` envelope.
- Invalid identity/filter trả stable `ERR_INVALID_REQUEST`.
- Không tìm thấy page trả `ERR_NOT_FOUND`.
- Không có current publication trả `ERR_PUBLICATION_UNAVAILABLE`.
- Missing frequency, seasonality, fare hoặc commercial-connection truth giữ `unknown`/`unavailable`.
- Không suy luận year-round, protected connection, through baggage, live availability hoặc fare rule.
- Raw SQL/provider errors không ra public response.

## 11. Security và data rights

- Public tables bật RLS và không cấp domain writes cho browser roles.
- Public RPC chỉ executable bởi `service_role`; Next.js/Edge transport giữ secret server-side.
- Privileged functions ở private schema, có explicit `search_path` và least privilege.
- Published data bắt buộc source rights, display/derived-data permission, confidence và freshness.
- Fixture luôn development-only và `noindex`.
- OpenFlights bị cấm hoàn toàn.

## 12. Migration strategy

`supabase/sql_src` là source of truth. Không sửa migration generated thủ công.

Thứ tự:

1. Viết contract assertions đỏ cho schema và RPC canonical.
2. Bổ sung/điều chỉnh typed tables và private composers.
3. Xây canonical route projection.
4. Xây read-model publication pipeline.
5. Xây `rpc_get_page` và `rpc_search_routes`.
6. Chuyển Edge handlers/tests sang canonical names.
7. Chạy dependency audit và xoá duplicate/legacy objects khỏi `sql_src`.
8. Regenerate clean migrations bằng script repo.
9. Reset local Supabase từ migration + seed.
10. Chạy SQL behavior, RLS, privilege, Edge, contract và E2E checks.

## 13. Testing và acceptance

### Schema tests

- Một table definition mỗi file.
- Constraints cho locale, status, page identity, order, source và freshness.
- RLS/grants đúng trên mọi public table.

### Contract tests

- Bốn page type trả đúng typed payload.
- FAQ của mỗi page chỉ đến từ bảng FAQ tương ứng.
- Page content chỉ đến từ page-specific tables hoặc derived canonical facts.
- City/Airport route discovery mặc định direct-only.
- Route Page trả direct và connecting options đến ba stops.
- One-way fare chọn đúng trip type và không trở thành live price claim.

### Duplicate tests

- Source scan không còn `_v2`, legacy RPC names hoặc hai public functions cùng capability.
- `pg_proc` và dependency audit xác nhận chỉ còn canonical pSEO/search functions.
- Edge allowlist không tham chiếu function đã xoá.

### Publication tests

- Incomplete, stale, unlicensed hoặc invalid payload không thể promote indexable.
- Atomic rollback giữ current good publication khi candidate fail.
- Sitemap chỉ chứa page thuộc current publication và vượt indexability gate.

### Definition of Done

- Local database rebuild thành công từ clean generated migration và seed.
- SQL checks, RLS/privilege checks, Deno/Edge tests và E2E contract tests chạy xanh.
- Không có hardcoded aviation facts/page editorial content trong transport.
- Không còn duplicate, `_v2` hoặc legacy pSEO/route-search RPC/function trong SQL source và database.

## 14. Ngoài phạm vi

- Header, footer, navigation, control/filter labels và Terms.
- Live booking/checkout.
- Provider integration production khi chưa có rights approval.
- Advertisement/affiliate campaign schema trong phase triển khai này; chỉ giữ boundary để bổ sung khi
  P3 bắt đầu.
