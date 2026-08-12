# Lộ trình kỹ thuật MVP Tripways

**Trạng thái:** Đang thực hiện — phase hiện tại P0A
**Cập nhật:** 2026-08-05
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
- OurAirports cung cấp reference data; Travelpayouts adapter normalize content observations theo
  `flight-content-observations.v1`.
- City aggregation, region taxonomy, codeshare dedupe, frequency, confidence và indexability thuộc
  Tripways.
- Observation được giữ tối đa 24 giờ, không lưu raw payload, không lưu lịch sử và được thay nguyên
  batch. Cron kiểm tra mỗi ngày và chỉ fetch lại khi batch đã sang ngày thứ 6.
- Affiliate handoff chỉ ghép relative provider path với allowlisted Aviasales host ở server; client
  không truyền destination URL.
- AeroDataBox/AirLabs không có credential, cron, adapter hoặc schema trong implementation hiện tại.
  Schedule provider tương lai phải đi qua adapter riêng và rights gate mới.
- Contract giá và affiliate phải optional, có capability gating và kill switch; tắt chúng không làm
  hỏng City Hub.

## 10. Contract pSEO mục tiêu theo phase

### P0A/P0B

- **Đã triển khai foundation local:** chỉ giữ `rpc_get_page` và `rpc_search_routes` làm contract
  canonical versionless; public page/route RPC legacy đã được xoá khỏi source, Edge và SQL e2e đang
  hoạt động.
- **Đã triển khai foundation local:** typed Homepage/City/Airport/Route content và FAQ tables,
  publication version, immutable read models, locale/source/review/freshness fields và route projection
  dùng chung.
- Page payload dùng discriminated page type và chứa `identity`, `seo`, `modules`, `internal_links`,
  `commercial`, `freshness`, `provenance` và `indexability`.
- `modules` có type, stable key, display order, localized copy, data payload và explicit empty-state
  policy. Frontend chỉ ánh xạ module type sang component.
- Publication build phải fail khi JSON payload sai schema; request path chỉ đọc snapshot đã publish.
- Airport payload dùng journey contract riêng và không nhúng route array. Verified flights gọi
  `rpc_search_routes` bằng airport scope from/to, luôn direct-only.

### P1

- Thêm content workflow, source rights, verification timestamp và completeness scoring cho các module
  editorial/airport guidance.
- Airport completeness yêu cầu reviewed arrival/departure/transport; airport identity hợp lệ không
  tự tạo verified-flight inventory hoặc indexability.
- Không cho fixture, draft, unreviewed content hoặc source thiếu production rights đi vào current
  publication version.

### P2

- `flight_route_options` là projection duy nhất cho global, origin-city, airport-from, airport-to và
  city-pair.
- Generic discovery bổ sung geography, departure-airport, duration và estimated-price facets.
  Airport scope chỉ nhận counterpart query/country/region, domestic/international và operating
  airline; SQL ép `stop_count = 0` và airport đúng endpoint theo direction.
- Price projection giữ state `available|missing|expired|unlicensed`; không dùng zero để thay dữ liệu
  thiếu và không trộn với live offer.

### P3

- Thêm backend contract cho ad placement, sponsored placement, affiliate offer, disclosure, partner
  capability và kill switch.
- Redirect dùng allowlist/signed identifier; frontend không nhận arbitrary destination URL.
- Ad/affiliate analytics không được thay đổi organic module payload hoặc indexability truth.
- Airport live-search prefill chỉ nhận verified direct row đã chọn; commercial placement không được
  chen vào ordered journey steps hoặc thay đổi direct-flight ranking.

### P4

- Materialize completeness, uniqueness, demand, rights và freshness scores theo page/version.
- Sitemap chỉ đọc indexable current publication; chia shard theo page type/market và có lastmod thật.
- Rollout theo cohort, đo cache hit, RPC latency, publication duration, crawl waste, stale rate và cost
  per published/indexed page.
- Có budget, anomaly gate và atomic rollback trước khi tăng số URL theo cấp số lớn.
