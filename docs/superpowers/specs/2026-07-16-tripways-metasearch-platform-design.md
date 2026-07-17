# Thiết kế nền tảng Flight Metasearch Tripways

**Trạng thái:** Sẵn sàng để người dùng review  
**Ngày:** 2026-07-16  
**Phạm vi:** Route discovery, interactive pSEO, live flight search, affiliate redirect và analytics
theo kiến trúc không phụ thuộc provider cụ thể

## 1. Mục tiêu

Xây dựng Tripways thành sản phẩm flight metasearch có khả năng:

- Tạo các trang pSEO hữu ích và có tính tương tác cho quốc gia, thành phố, sân bay, hãng bay và
  tuyến bay.
- Cho phép người dùng khám phá route bay thẳng và một điểm dừng từ dữ liệu lịch bay có license.
- Lọc route theo hãng bay, thời lượng, điểm transit, lịch hoạt động và độ tin cậy.
- Tìm lịch bay theo ngày và giá live thông qua một aggregator adapter.
- Chuyển người dùng sang airline hoặc OTA partner để hoàn tất booking.
- Chạy đầy đủ ở local trước khi có hợp đồng và credentials của provider thật.

Tripways không phát hành vé, không thu tiền booking và không xử lý hủy vé.

## 2. Ranh giới source of truth

### Route graph trong Supabase

Supabase lưu dữ liệu tương đối ổn định được publish từ snapshot hằng ngày:

- Quốc gia, thành phố, sân bay và hãng bay.
- Các flight route có hướng.
- Schedule pattern của chuyến bay.
- Các route option bay thẳng và một điểm dừng được tính trước.
- Nguồn dữ liệu, quyền license, confidence và freshness.
- Page read model và trạng thái indexability.

Lớp này trả lời: “Những route và scheduled connection nào thường tồn tại?”. Nó không khẳng định
còn ghế hoặc giá hiện tại.

### Live aggregator

Live aggregator được gọi khi người dùng nhập ngày, số hành khách và cabin. Nó trả về lịch bay theo
ngày, flight number, operating airline, số điểm dừng, duration, offer, giá và affiliate deeplink.

Lớp này trả lời: “Provider hiện trả về những offer nào cho dated search này?”.

### Chế độ local không phụ thuộc provider

Local development sử dụng các deterministic adapter triển khai cùng contract với production:

- Fixture schedule-snapshot adapter.
- Fixture live-search adapter.
- Fixture affiliate partner/deeplink adapter.

Fixture được đánh dấu development-only và không thể trở thành dữ liệu production hoặc SEO-indexable.

## 3. Ranh giới feature

### 3.1 Data Ingestion

Sở hữu raw snapshot, provider adapter, validation, normalization, diff và atomic publication.

Feature này có thể ghi normalized domain tables nhưng không triển khai route search hoặc page
presentation.

### 3.2 Route Discovery

Sở hữu direct/one-stop options, connection compatibility, filters, facets và ranking trên dữ liệu
schedule đã publish.

Feature này không gọi live pricing provider.

### 3.3 Interactive pSEO

Sở hữu read model cho country, city, airport, airline và route page; canonical URL, indexability,
sitemap entry và cache metadata.

Feature này consume dữ liệu route discovery đã publish và không lặp lại routing rules.

### 3.4 Live Flight Search

Sở hữu dated-search validation, provider adapter orchestration, asynchronous polling khi cần, offer
normalization, deduplication, filtering, facets và live ranking.

Feature này có thể dùng route-discovery candidates để loại request bất khả thi hoặc cải thiện lời gọi
provider, nhưng route data trong Supabase không bao giờ thay thế live provider result.

### 3.5 Affiliate Redirect

Sở hữu partner-domain allowlist, outbound token ngắn hạn, click capture và safe redirect tới
airline/OTA deeplink do provider cung cấp.

Feature này không nhận redirect URL tùy ý từ client.

### 3.6 Product Analytics

Sở hữu các event có allowlist và giới hạn kích thước cho search, filter, pSEO interaction, no-result,
provider latency/error và affiliate click.

Feature này không lưu đầy đủ thông tin hành khách, authorization header hoặc raw provider payload.

## 4. Kiến trúc dữ liệu

### PostgreSQL schemas

- `public`: normalized domain tables và safe read contracts; mọi table đều bật RLS.
- `private`: raw snapshot, unpublished staging rows và short-lived provider cache khi được phép.
- `admin`: data source, ingestion run, validation issue, publish state và provider operation.
- `analytics`: append-only product events và affiliate events.

### Các normalized table hiện có

- `admin.data_sources`
- `public.countries`
- `public.cities`
- `public.airports`
- `public.airlines`
- `public.flight_routes`

### Schedule tables

`public.flight_services` lưu schedule pattern có thể tái sử dụng:

- Route và airline references.
- Flight number.
- Ngày `valid_from` và `valid_to`.
- Các ngày hoạt động trong tuần.
- Giờ khởi hành/đến theo local time và arrival-day offset.
- Scheduled duration và aircraft type nếu provider cung cấp.
- Source, confidence và verification timestamps.

Đây không phải live availability table.

### Route option read model

`public.route_options` lưu các direct và one-stop option đã được tính trước và publish:

- Origin và final destination.
- Danh sách leg/service có thứ tự.
- Stop count và connection airports.
- Operating và marketing airlines.
- Tổng flight duration, layover duration và journey duration.
- Tóm tắt local departure/arrival time.
- Validity window và operating days chung.
- Confidence, frequency, data version và freshness.

Table này được rebuild theo transaction sau mỗi lần publish daily schedule thành công. Đây là read
model, không phải source of truth được chỉnh sửa độc lập.

### pSEO read models

Read model cung cấp page payload có giới hạn rõ ràng cho:

- Country route networks.
- City airport và route networks.
- Airport direct destinations và airlines.
- Airline network coverage.
- Origin-destination route pages.
- Sitemap/indexability entries.

Chỉ dữ liệu có license production phù hợp, đủ mới và đủ confidence mới được index.

### Live-search state

Nền tảng chỉ lưu operational search state cần thiết cho asynchronous provider API:

- Tripways search ID dạng opaque.
- Provider request/token reference.
- Normalized request fingerprint.
- Status, timestamps và sanitized error code.
- Expiry time.

Offer và price chỉ được cache khi provider terms cho phép và chỉ tới `expires_at`.

## 5. Kiến trúc filter

### Route-discovery filters

Database áp dụng filter trên `route_options`:

- Airlines.
- Direct hoặc one-stop.
- Connection airport được include/exclude.
- Maximum total duration.
- Maximum layover duration.
- Departure/arrival time window.
- Operating days và schedule validity.
- Confidence và freshness threshold.

Response trả thêm facets cho airlines, stops, connections và duration ranges hiện có. Ranking ổn
định theo thứ tự: ít điểm dừng hơn, duration ngắn hơn, confidence/frequency cao hơn, connection tốt
hơn và geographic detour thấp hơn.

### Live-offer filters

Live-search layer lọc normalized provider offers theo:

- Price và currency.
- Airlines.
- Stops.
- Total duration và layover.
- Departure/arrival time.
- Airports, cabin, baggage và fare attributes khi provider cung cấp.

Với result set có kích thước giới hạn, backend lọc trên normalized results. Với provider-controlled
pagination hoặc polling, các filter được provider hỗ trợ sẽ được chuyển qua adapter.

## 6. Kiến trúc API

### Public cacheable reads

- `GET /api/routes/search`
- `GET /api/pages/countries/:slug`
- `GET /api/pages/cities/:slug`
- `GET /api/pages/airports/:slug`
- `GET /api/pages/airlines/:slug`
- `GET /api/pages/routes/:slug`
- `GET /api/sitemap`

Các endpoint này đọc Supabase RPC/read models và trả data-version, freshness cùng cache metadata.

### Live search

- `POST /api/live-flights/search`
- `GET /api/live-flights/search/:searchId`

POST bắt đầu provider-neutral search. GET hỗ trợ provider cần polling. Synchronous fixture provider có
thể trả completed search ngay nhưng vẫn giữ cùng contract.

### Affiliate redirect

- `POST /api/outbound/token`
- `GET /api/outbound/:token`

Token có thời hạn ngắn và chỉ resolve tới partner domain/deeplink đã được validate trước đó.

### Analytics

- `POST /api/events`

Event có allowlist, bị giới hạn kích thước, rate limited và không nhận arbitrary user payload.

## 7. Quy tắc pSEO

- Base entity và route URL là canonical URL và có thể index.
- Filter query parameter tùy ý mặc định `noindex` và canonicalize về base page.
- Curated filtered landing page cần explicit template, đủ dữ liệu và có search demand được chứng minh.
- Trang empty, fixture-only, stale, historical, inactive hoặc low-confidence bị loại.
- Sitemap generation đọc precomputed indexability model thay vì chạy graph query.

## 8. Security và reliability

- Public tables tiếp tục dùng RLS và client không có quyền ghi.
- Raw/provider schemas không được expose qua Data API.
- Service-role và provider secrets chỉ tồn tại server-side.
- Ingestion được authenticate, idempotent, validate và publish theo transaction.
- Live search có bounded input, rate limit, timeout, normalized provider errors và circuit protection.
- Affiliate redirect enforce partner-domain allowlist và signed/opaque token có thời hạn.
- Log chứa request ID và operational metadata nhưng không chứa secret hoặc raw passenger data.
- Provider failure không biến “route tồn tại” thành “route không tồn tại”. Page vẫn sử dụng được, còn
  live-price UI báo tạm thời không thể tải giá.

## 9. Cache strategy

- pSEO/page data: HTTP/CDN cache theo data version.
- Route discovery: cache normalized filter và pagination theo data version.
- Live search: mặc định không durable cache; chỉ dùng TTL ngắn khi provider terms cho phép.
- Affiliate token: backend-owned record ngắn hạn hoặc signed token, không dùng URL do browser gửi.
- Chỉ thêm Redis khi polling, rate limiting hoặc live-search concurrency chứng minh Postgres và HTTP
  cache không đủ.

## 10. Testing strategy

- SQL contract tests cho one-object-per-file, constraints, RLS và privileges.
- SQL behavior tests cho valid/invalid sources, services, direct options và one-stop compatibility.
- Deterministic fixture-adapter tests cho ingestion và live offers.
- Route-discovery tests cho filtering, facets, stable ranking và pagination.
- pSEO tests cho canonical, indexability và sitemap rules.
- Live-search tests cho normalization, deduplication, polling, expiry, timeout và provider errors.
- Affiliate tests cho allowlist, token expiry, tampering và event capture.
- Local end-to-end flow: publish fixture snapshot → query route → load pSEO page data → chạy dated
  live search → lọc offer → resolve affiliate redirect.
- Chạy Supabase reset, schema lint, security advisor, performance advisor, Deno checks, API build và
  toàn bộ relevant test suite trước khi hoàn tất.

## 11. Thứ tự delivery

Mỗi phase phải tạo ra behavior chạy được trước khi chuyển sang phase tiếp theo:

1. Route Discovery với deterministic fixture data.
2. Interactive pSEO trên route-discovery read models.
3. Provider-neutral ingestion với daily atomic publish.
4. Provider-neutral live search với fixture offers.
5. Safe affiliate redirect và click tracking.
6. Product analytics, operational guards và full end-to-end verification.

Provider schedule và live provider thật sẽ được tích hợp sau bằng cách triển khai các adapter đã duyệt
mà không thay đổi domain/API contracts.

## 12. Ngoài phạm vi

- Booking, payment, ticket issuance, cancellation, refund và customer-support workflows.
- Redirect URL do user cung cấp.
- Dữ liệu OpenFlights.
- Lưu live offer hoặc price dài hạn khi chưa có quyền từ provider.
- Generic multimodal graph tables trước khi triển khai một transport mode ngoài flight.
- Redis, queue hoặc infrastructure bổ sung khi chưa có nhu cầu đo được.
- Remote Supabase linking/deployment và real provider credentials trong implementation cycle này.
