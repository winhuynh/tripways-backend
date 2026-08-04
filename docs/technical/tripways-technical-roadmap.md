# Lộ trình kỹ thuật MVP Tripways

**Trạng thái:** Đang thực hiện — phase hiện tại P0A
**Cập nhật:** 2026-08-04
**Phạm vi:** `tripways-backend`, `tripways-web`

## 1. Mục đích

Tài liệu này định nghĩa thứ tự kỹ thuật và hợp đồng giữa các phase của Tripways. PRD sản phẩm mô tả
giá trị cần bàn giao; PRD kỹ thuật mô tả hệ thống phải được xây như thế nào và bằng chứng nào được
dùng để nghiệm thu.

## 2. Thứ tự bắt buộc

```text
P0A Local Release Candidate
  → P0B Remote Staging
    → P1 Production Data Ingestion
      → P2 Licensed Flight Data
        → P3 Commercial MVP
          → P4 Controlled pSEO Scale
```

| Phase | Trạng thái         |
| ----- | ------------------ |
| P0A   | **Đang thực hiện** |
| P0B   | Chưa bắt đầu       |
| P1    | Chưa bắt đầu       |
| P2    | Chưa bắt đầu       |
| P3    | Chưa bắt đầu       |
| P4    | Chưa bắt đầu       |

Foundation được triển khai sớm cho phase sau không thay thế dependency hoặc cổng nghiệm thu của
phase đó.

Không triển khai song song các phase có dependency dữ liệu trực tiếp. Nghiên cứu provider và giấy
phép có thể chạy song song, nhưng không được đưa provider vào code production trước khi phase trước
đạt cổng nghiệm thu.

## 3. Ranh giới kiến trúc xuyên suốt

### PostgreSQL và RPC

- Là source of truth cho invariant domain, idempotency, publication, route ranking và indexability.
- Dữ liệu raw, staging, vận hành và analytics nằm ngoài schema expose.
- Mọi bảng trong schema expose bật RLS trước khi cấp quyền.
- Hàm đặc quyền đặt trong schema private, có `search_path` rõ ràng và quyền tối thiểu.

### Supabase Edge Functions

- Xử lý transport có đặc quyền: ingestion, event write, affiliate write và thao tác tài khoản.
- Trong P0A, unified `page-query`, `route-search-query` và `sitemap-query` là backend data gateway
  phục vụ server-side web boundary; browser không được giữ service-role key hoặc gọi RPC đặc quyền.
- Chỉ thực hiện parse, validation, authentication, authorization, rate limit, gọi RPC, normalize lỗi,
  log và trả response.
- Không sao chép invariant publication, ranking hoặc indexability từ PostgreSQL.

### Next.js

- Server Components tải dữ liệu trang.
- Route Handlers hoặc server repository thống nhất sở hữu public web boundary, cache header, request
  identity và HTTP response envelope.
- Client Components chỉ sở hữu tương tác trình duyệt.
- Không chuyển khóa bí mật, raw database object hoặc provider payload sang client.
- Frontend render page read model; không hardcode content SEO, UX copy, CTA thương mại hoặc fallback
  có thể biến thành nội dung công khai trên hàng triệu URL.

### Adapter provider

- Provider-specific code ánh xạ payload sang contract canonical.
- Domain và public API không phụ thuộc tên provider.
- Mọi adapter có deterministic fixture chạy offline.

## 4. Hợp đồng phản hồi chung

Domain RPC/backend gateway dùng envelope tối thiểu ổn định:

```json
{
  "data": {},
  "meta": { "data_version": "string-or-uuid" },
  "error": null
}
```

Public HTTP boundary mở rộng envelope bằng metadata vận hành:

```json
{
  "data": {},
  "meta": {
    "request_id": "uuid",
    "generated_at": "ISO-8601",
    "data_version": "string-or-uuid",
    "freshness": {},
    "cache": {
      "status": "HIT|MISS|BYPASS",
      "max_age_seconds": 300
    }
  },
  "error": null
}
```

Lỗi không trả raw SQL, provider payload, stack trace, secret hoặc thông tin vận hành nhạy cảm.

## 5. Chiến lược môi trường

| Môi trường | Dữ liệu                                   | Index                 | Bí mật          | Mục đích                               |
| ---------- | ----------------------------------------- | --------------------- | --------------- | -------------------------------------- |
| Local      | Fixture, mock provider, API thật giới hạn | Không                 | Local-only      | Phát triển và kiểm thử 90% hành vi     |
| Staging    | Fixture hoặc snapshot đã sanitize         | Không                 | Staging-only    | Xác minh cloud, network, cache, deploy |
| Production | Nguồn đã phê duyệt                        | Theo publication gate | Production-only | Phục vụ người dùng thật                |

Không dùng chung Supabase project, service-role key hoặc provider credential giữa staging và
production.

## 6. Source of truth trong kho mã

- SQL duy trì tại `tripways-backend/supabase/sql_src`.
- Migration được sinh xác định tại `tripways-backend/supabase/migrations`.
- Fixture tại `tripways-backend/supabase/seed`.
- Edge Functions tại `tripways-backend/supabase/functions/v1`.
- Web feature code tại `tripways-web/src/features`.
- Next.js entries và public Route Handlers tại `tripways-web/src/app`.
- PRD sản phẩm tại `tripways-backend/docs/product`.
- PRD kỹ thuật tại `tripways-backend/docs/technical`.

## 7. Kiểm thử bắt buộc xuyên suốt

- Unit test parser, validator, normalizer và pure domain behavior.
- SQL contract test cho schema, RLS, privilege và function boundary.
- SQL behavior/E2E test có rollback.
- Edge handler test cho method, auth, input, response và lỗi.
- Web DTO test cho mọi external envelope.
- Web component/page test cho loading, empty, error và metadata.
- Production build, lint, typecheck và format.
- Remote smoke test chỉ ở P0B trở đi.
- Security và performance advisor trước mỗi launch gate remote.

## 8. Quy tắc hoàn tất

Một phase chỉ hoàn tất khi:

- Mọi acceptance criterion có bằng chứng.
- Không còn placeholder hoặc code path chỉ hoạt động bằng fixture nếu phase yêu cầu production.
- Không có secret trong git hoặc client bundle.
- Không còn migration chưa được tái dựng và kiểm chứng.
- Tài liệu vận hành, rollback và phần bị hoãn được cập nhật.
- Thao tác external hoặc production được chủ sở hữu phê duyệt.

## 9. Provider boundary cho City Hub

Chi tiết quyết định nằm tại `docs/product/city-hub-provider-and-commercial-expansion-plan.md`.

- Không provider call nào nằm trong page-render path; ingestion và publication tạo read model trước.
- AirLabs adapter, nếu được duyệt ở P2, chỉ normalize route, recurring schedule và reference data.
- City aggregation, region taxonomy, codeshare dedupe, frequency, confidence và indexability thuộc
  Tripways.
- Price observation, live offer và affiliate redirect dùng contract/adapters riêng ở P3.
- Contract giá và affiliate phải optional, có capability gating và kill switch; tắt chúng không làm
  hỏng City Hub.

## 10. Contract pSEO mục tiêu theo phase

### P0A/P0B

- Hợp nhất `rpc_get_page_v2` và các `rpc_get_*_page` thành một chiến lược canonical, versionless;
  tương tự chỉ giữ một route-search contract production.
- Page payload dùng discriminated page type và chứa `identity`, `seo`, `modules`, `internal_links`,
  `commercial`, `freshness`, `provenance` và `indexability`.
- `modules` có type, stable key, display order, localized copy, data payload và explicit empty-state
  policy. Frontend chỉ ánh xạ module type sang component.
- Publication build phải fail khi JSON payload sai schema; request path chỉ đọc snapshot đã publish.

### P1

- Thêm content workflow, source rights, verification timestamp và completeness scoring cho các module
  editorial/airport guidance.
- Không cho fixture, draft, unreviewed content hoặc source thiếu production rights đi vào current
  publication version.

### P2

- `route_search_options` là projection duy nhất cho global, origin-city, origin-airport và city-pair.
- Bổ sung filter/facet cho destination country/region, departure airport, domestic/international,
  duration và estimated one-way price.
- Price projection giữ state `available|missing|expired|unlicensed`; không dùng zero để thay dữ liệu
  thiếu và không trộn với live offer.

### P3

- Thêm backend contract cho ad placement, sponsored placement, affiliate offer, disclosure, partner
  capability và kill switch.
- Redirect dùng allowlist/signed identifier; frontend không nhận arbitrary destination URL.
- Ad/affiliate analytics không được thay đổi organic module payload hoặc indexability truth.

### P4

- Materialize completeness, uniqueness, demand, rights và freshness scores theo page/version.
- Sitemap chỉ đọc indexable current publication; chia shard theo page type/market và có lastmod thật.
- Rollout theo cohort, đo cache hit, RPC latency, publication duration, crawl waste, stale rate và cost
  per published/indexed page.
- Có budget, anomaly gate và atomic rollback trước khi tăng số URL theo cấp số lớn.
