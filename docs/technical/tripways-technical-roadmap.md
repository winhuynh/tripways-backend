# Lộ trình kỹ thuật MVP Tripways

**Trạng thái:** Sẵn sàng để lập kế hoạch triển khai  
**Ngày:** 2026-07-30  
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
```

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
- Chỉ thực hiện parse, validation, authentication, authorization, rate limit, gọi RPC, normalize lỗi,
  log và trả response.
- Không sao chép invariant publication, ranking hoặc indexability từ PostgreSQL.

### Next.js

- Server Components tải dữ liệu trang.
- Route Handlers sở hữu public HTTP read boundary, cache header, request identity và response envelope.
- Client Components chỉ sở hữu tương tác trình duyệt.
- Không chuyển khóa bí mật, raw database object hoặc provider payload sang client.

### Adapter provider

- Provider-specific code ánh xạ payload sang contract canonical.
- Domain và public API không phụ thuộc tên provider.
- Mọi adapter có deterministic fixture chạy offline.

## 4. Hợp đồng phản hồi chung

Public read và transport nội bộ dùng envelope ổn định:

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
