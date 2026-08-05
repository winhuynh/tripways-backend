# PRD kỹ thuật P2: Dữ liệu tuyến và lịch bay có bản quyền

**PRD sản phẩm liên quan:** `docs/product/p2-licensed-flight-data-prd.md`  
**Phụ thuộc:** P1 hoàn tất và provider rights được phê duyệt
**Trạng thái:** Chưa bắt đầu — canonical graph/read-model foundation không phải P2 acceptance
**Cập nhật:** 2026-08-05

Canonical route/service tables, 0–3-stop graph search, page read models và estimated-price schema
được chuẩn bị sớm trong P0A. P2 chỉ bắt đầu sau P1 và chỉ được nghiệm thu bằng licensed provider,
production rights, staging publication và remote evidence.

## 1. Kiến trúc

```text
Licensed schedule provider
  → provider adapter
    → P1 ingestion state machine
      → canonical flight_routes + flight_services
        → refresh_route_options()
          → refresh_pseo_read_models()
            → versioned public read APIs
```

Provider adapter không được ghi trực tiếp vào bảng published.

## 2. Provider rights contract

`admin.data_sources` phải biểu diễn:

- Storage allowed và retention.
- Production display allowed.
- SEO allowed.
- Caching allowed và TTL tối đa.
- Derived data allowed.
- Attribution text/URL.
- Effective/expiry date của quyền.

Publication RPC từ chối batch khi quyền không đáp ứng mục đích publish.

## 3. Canonical schedule contract

Route:

- Origin/destination airport.
- Directional identity.
- Operating/marketing airline khi có.
- Source status, confidence và verification timestamp.

Recurring service:

- Flight number.
- Valid-from/valid-to.
- Operating weekdays.
- Local departure/arrival time.
- Arrival-day offset.
- Scheduled duration.
- Aircraft/equipment khi được phép.
- Frequency và seasonality nullable.

Không lưu live availability hoặc fare trong các bảng này.

### 3.1 Capability boundary của AirLabs

Với contract API được review tại thời điểm tích hợp, AirLabs có thể cung cấp dữ liệu hàng không phục
vụ P2 như route, lịch định kỳ, flight number, sân bay, thời gian, ngày khai thác, duration, aircraft
khi có và các trường codeshare. Adapter phải ánh xạ rõ:

- `airline_*`/`flight_*`: marketing carrier/flight theo semantics đã xác minh với provider.
- `cs_airline_*`/`cs_flight_*`: operating carrier/flight của codeshare theo semantics đã xác minh.
- Field thiếu hoặc coverage không chắc chắn: `null`/`unknown`, không tự điền từ dữ liệu gần giống.

AirLabs Routes/Schedules không phải flight-shopping hoặc ticketing response. Nếu payload/contract
được phê duyệt không cung cấp bằng chứng explicit, nó không xác nhận:

- Các leg được bán trong cùng một offer hoặc cùng một vé.
- Số lượng vé hay validating carrier của toàn itinerary.
- Kết nối được bảo vệ khi delay/misconnect.
- Self-transfer hay airport/terminal transfer do người dùng tự thực hiện.
- Hành lý được check-through đến điểm cuối.
- Fare, availability, fare rules hoặc khả năng đặt hành trình nhiều leg.

Không được suy luận các thuộc tính trên từ cùng airline, alliance, codeshare, airport/terminal hoặc
layover compatibility. Khi AirLabs thay đổi version hoặc field semantics, adapter contract test và
capability matrix phải được review lại trước khi publish.

### 3.2 Commercial connection truth trong P2

Mỗi `route_option` nhiều leg phải có contract an toàn sau ở public read model, dù implementation có
thể tính từ constant thay vì lưu lặp trong từng row:

```text
commercial_status: schedule_only
ticketing_type: unknown
protected_connection: unknown
self_transfer: unknown
through_baggage: unknown
validating_carrier: null
commercial_evidence: unavailable
```

Không expose boolean `false` khi giá trị thực tế là chưa biết. `unknown` khác với `false`: ví dụ
`self_transfer: unknown` không có nghĩa hành trình được bảo vệ. API phải kèm disclaimer ổn định rằng
kết quả được tạo từ stored schedules và cần live offer để xác nhận khả năng bán cùng điều kiện vé.

## 4. Publication transaction

Một publication schedule thành công phải:

1. Validate rights và batch state.
2. Resolve airport/airline references.
3. Publish route/service canonical.
4. Deactivate theo explicit provider rule.
5. Rebuild zero-to-three-stop `route_options`.
6. Rebuild affected pSEO read models.
7. Tính indexability.
8. Tạo data version mới.
9. Ghi publish diff và freshness.

Nếu bước nào fail, rollback toàn bộ version mới.

## 5. Route discovery

- Hỗ trợ từ không đến ba connection; `stop_count` là số sân bay nối chuyến trung gian.
- Database sở hữu minimum/maximum layover, compatibility, ranking và facets.
- Ranking ổn định: stops, duration, confidence, frequency, connection quality, stable tie-breaker.
- Shared input gồm scope toàn cục, origin city, airport hai chiều hoặc city pair. Generic discovery
  có thể dùng airlines, connection airports, stops, duration, layover, cabin và price/currency khi
  có quyền hiển thị.
- Airport Page dùng scope `{ type: "airport", key, direction: "from" | "to" }`; SQL ép direct-only
  và public parser chỉ nhận counterpart query/country/region, domestic/international và operating
  airline. Không alias scope này thành `origin_airport`, vì inbound cần destination airport cố định.
- Pagination dùng bounded page size và deterministic keyset cursor. Operating-day/departure-window
  chỉ thêm khi licensed schedule contract và UX tương ứng được phê duyệt.
- Missing schedule data không bị chuyển thành zero/year-round.

## 6. pSEO read models

P2 hoàn thiện:

- Homepage discovery read model.
- City origin pages.
- Airport pages.
- Route detail read model tối thiểu.
- Sitemap/indexability source.

Airport read model là journey-led và không nhúng route arrays: orientation, quick answers, arrival,
departure, transport, curated airport modules, FAQ, internal links và provenance. Verified direct
flights được đọc riêng từ current `route_search_options`; chỉ row `stop_count = 0` tạo từ published
licensed schedule mới đủ điều kiện. `route_options` nhiều leg không được đưa vào Airport Page.

Country và airline page chỉ thêm nếu initial inventory và search intent được phê duyệt; không bắt
buộc để nghiệm thu core P2.

## 7. Public API

Next.js Route Handlers:

```text
GET /api/pages/cities/:slug
GET /api/pages/airports/:slug
GET /api/pages/homepage
GET /api/routes/search
GET /api/pages/routes/:slug
GET /api/sitemap
```

- Validate input runtime.
- Gọi RPC/read model, không duplicate SQL business logic.
- Trả envelope chung.
- Có `Cache-Control`, ETag/version hoặc platform revalidation phù hợp.
- Error không tiết lộ provider hoặc SQL.

## 8. Cache

- Cache key: endpoint + normalized identity/filter/locale + data version.
- TTL không vượt provider rights và freshness threshold.
- Publication đổi version, không cần purge toàn cục nếu URL/version strategy đủ.
- Error, preview và non-indexable response không cache như production SEO content.
- Chỉ thêm Redis khi có bằng chứng platform cache không đủ.

## 9. Indexability

Page chỉ index khi:

- Source production/SEO/derived rights hợp lệ.
- Freshness trong ngưỡng.
- Confidence trong ngưỡng.
- Có capability gate theo page type. Airport yêu cầu reviewed arrival/departure/transport và ít nhất
  một verified direct route; City/Route Page dùng route-depth gate riêng.
- Metadata/editorial đã review.
- Canonical identity duy nhất.
- Không chứa fixture.

Indexability thuộc PostgreSQL. Web chỉ phản ánh quyết định.

## 10. Freshness và failure behavior

- Provider failure giữ version published trước.
- Missed ingestion tạo alert.
- Stale page có policy noindex hoặc warning theo threshold.
- “Không có dữ liệu” khác “không có tuyến”.
- Không mô tả schedule stored là live.

## 11. Kiểm thử

- Provider adapter fixture tests.
- Rights matrix tests.
- Schedule normalization tests.
- AirLabs field-semantics và missing-field normalization tests.
- Tests chứng minh P2 không suy luận ticketing/protection/self-transfer/through-baggage từ airline,
  alliance, codeshare, terminal hoặc layover.
- Public contract tests phân biệt `unknown` với `false` và luôn trả schedule-only disclaimer cho
  route nhiều leg.
- Zero-to-three-stop compatibility and ranking tests.
- Atomic publication + read-model rebuild E2E.
- Indexability matrix tests.
- Cache/version contract tests.
- Sitemap excludes fixture/stale/unlicensed pages.
- Load test common route/city/airport queries.
- Remote smoke test trên licensed staging snapshot.

## 12. Cổng nghiệm thu

- Snapshot provider có bản quyền publish nguyên tử ở staging.
- Route discovery 0–3 stops đúng và deterministic.
- Initial city/airport inventory đã review.
- Sitemap chỉ gồm page đủ điều kiện.
- Cache tuân thủ provider rights.
- Freshness alert và rollback đã kiểm chứng.
- Không có live price/availability claim.
- AirLabs capability matrix đã được xác minh theo API version/contract sử dụng và mọi commercial
  connection field không được nguồn cung cấp đều trả `unknown`/`unavailable`.

## 13. Thao tác cần approval

- Provider contract và rights matrix.
- Credentials.
- Production publication.
- Bật indexability và sitemap production.
- Thay đổi cache TTL dựa trên provider rights.

## 14. City Hub AirLabs POC kỹ thuật

Tham chiếu `docs/product/city-hub-provider-and-commercial-expansion-plan.md`.

- POC dùng khoảng 100 origin airports trong 14–30 ngày và đối chứng top routes, operating days,
  inactive routes cùng codeshare duplication.
- Acceptance mục tiêu: `>=95%` top-route endpoint accuracy, `>=90%` operating-day accuracy,
  `<3%` inactive route được publish active và `100%` codeshare trong mẫu có deterministic outcome.
- Adapter phải map provider fields vào canonical DTO; raw payload chỉ nằm private schema.
- Publication phải tính lại city aggregation, frequency, facets và affected City Hub read models.
- `seasonality_status` giữ `unknown` nếu contract không có dated evidence đủ điều kiện.
- Page query không gọi AirLabs; cache/read model đọc publication hiện hành.
- Price estimate, live offer và affiliate redirect không thuộc AirLabs adapter và không phải P2
  acceptance.

## 15. Route projection và estimated fare

- Hợp nhất route search trên `route_search_options`; không duy trì đồng thời
  `rpc_search_route_options` và `rpc_search_route_options_v2` sau compatibility window.
- Projection bổ sung destination country/region, domestic flag và facet; scope origin-city phải lọc
  được departure airport.
- Price join chọn đúng `trip_type = one_way` cho City/Route discovery, đúng stop bucket/cabin,
  production rights, currency và validity. Missing/expired/unlicensed là state riêng; Airport
  verified-flight response không dùng price làm filter hoặc content claim.
- Contract test bao phủ global, origin-city, airport-from, airport-to, city-pair, keyset pagination
  và facet count sau khi áp dụng filter hợp lệ. Hai airport direction phải chứng minh mọi result là
  direct và có airport cố định ở đúng endpoint.
