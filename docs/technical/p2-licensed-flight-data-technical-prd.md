# PRD kỹ thuật P2: Dữ liệu tuyến và lịch bay có bản quyền

**PRD sản phẩm liên quan:** `docs/product/p2-licensed-flight-data-prd.md`  
**Phụ thuộc:** P1 hoàn tất và provider rights được phê duyệt

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

## 4. Publication transaction

Một publication schedule thành công phải:

1. Validate rights và batch state.
2. Resolve airport/airline references.
3. Publish route/service canonical.
4. Deactivate theo explicit provider rule.
5. Rebuild direct và one-stop `route_options`.
6. Rebuild affected pSEO read models.
7. Tính indexability.
8. Tạo data version mới.
9. Ghi publish diff và freshness.

Nếu bước nào fail, rollback toàn bộ version mới.

## 5. Route discovery

- Hỗ trợ direct và tối đa một connection.
- Database sở hữu minimum/maximum layover, compatibility, ranking và facets.
- Ranking ổn định: stops, duration, confidence, frequency, connection quality, stable tie-breaker.
- Input gồm airport identity, airlines, exclude airports, duration, layover, departure window,
  operating day, limit và offset.
- Missing schedule data không bị chuyển thành zero/year-round.

## 6. pSEO read models

P2 hoàn thiện:

- City origin pages.
- Airport pages.
- Route detail read model tối thiểu.
- Sitemap/indexability source.

Country và airline page chỉ thêm nếu initial inventory và search intent được phê duyệt; không bắt
buộc để nghiệm thu core P2.

## 7. Public API

Next.js Route Handlers:

```text
GET /api/pages/cities/:slug
GET /api/pages/airports/:slug
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
- Có route depth tối thiểu.
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
- Direct/one-stop compatibility and ranking tests.
- Atomic publication + read-model rebuild E2E.
- Indexability matrix tests.
- Cache/version contract tests.
- Sitemap excludes fixture/stale/unlicensed pages.
- Load test common route/city/airport queries.
- Remote smoke test trên licensed staging snapshot.

## 12. Cổng nghiệm thu

- Snapshot provider có bản quyền publish nguyên tử ở staging.
- Route discovery direct/one-stop đúng và deterministic.
- Initial city/airport inventory đã review.
- Sitemap chỉ gồm page đủ điều kiện.
- Cache tuân thủ provider rights.
- Freshness alert và rollback đã kiểm chứng.
- Không có live price/availability claim.

## 13. Thao tác cần approval

- Provider contract và rights matrix.
- Credentials.
- Production publication.
- Bật indexability và sitemap production.
- Thay đổi cache TTL dựa trên provider rights.
