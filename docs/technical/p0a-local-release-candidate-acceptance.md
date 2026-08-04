# P0A Local Release Candidate Acceptance

**Trạng thái:** Đang thực hiện — chưa nghiệm thu
**Cập nhật:** 2026-08-04
**Phạm vi:** `tripways-backend`, `tripways-web`
**Indexing:** Tắt cho toàn bộ dữ liệu fixture và P0A

Tài liệu này là working acceptance record. Kết quả cũ ngày 2026-07-30 đã bị supersede vì backend
đã chuyển sang unified page/search gateway, thêm Homepage/Route Page read models và thay đổi source
state. Không tái sử dụng test count, endpoint name hoặc commit SHA từ lần review cũ.

## Capability Matrix

| #   | Capability                                             | Trạng thái hiện tại      | Bằng chứng cần để nghiệm thu                                       |
| --- | ------------------------------------------------------ | ------------------------ | ------------------------------------------------------------------ |
| 1   | Rebuild local Supabase từ migration và seed            | Ready to verify          | Migration regeneration và clean local reset trên source state cuối |
| 2   | Ingest batch hợp lệ từ mock provider                   | Ready to verify          | Provider tests và SQL ingestion E2E                                |
| 3   | Batch sai không làm hỏng dữ liệu tốt                   | Ready to verify          | Parser matrix và atomic rollback SQL E2E                           |
| 4   | Replay batch idempotent                                | Ready to verify          | Duplicate checksum/idempotency E2E                                 |
| 5   | Smoke approved real API với dữ liệu giới hạn           | Blocked external         | Approved HTTPS source, quyền sử dụng và credential khi cần         |
| 6   | Homepage chỉ link tới inventory tồn tại                | Cần verify backend + web | Inventory contract và browser smoke                                |
| 7   | City page load end-to-end                              | Cần verify backend + web | Unified page gateway, SSR và bounded error states                  |
| 8   | Airport page load end-to-end                           | Cần verify backend + web | Unified page gateway, SSR và bounded error states                  |
| 9   | Route Page và shared filters hoạt động                 | Cần verify backend + web | Page-shell, 0–3-stop search, filters, cursor và empty state        |
| 10  | Interactive map load hoặc fallback có chủ đích         | Cần verify web           | Desktop/mobile browser smoke                                       |
| 11  | Loading, 404 và dependency errors kết thúc             | Cần verify backend + web | DTO, component và browser failure tests                            |
| 12  | Format, lint, typecheck, tests, security và build pass | Cần rerun                | Full verification trên backend và web source state cuối            |

`Ready to verify` không có nghĩa `Pass`. Capability chỉ chuyển thành `Pass` khi lệnh và artifact
được ghi lại trên cùng source state cuối.

## Backend scope cần verify

- Mọi SQL source được migration generator đưa vào đúng một lần.
- Clean database reset hoàn tất với seed fixture.
- Raw data ở `private`, operational data ở `admin`, canonical/read models ở `public` với RLS và
  least-privilege grants.
- Base-data ingestion giữ atomicity, idempotency và development-only rights.
- Initial page load dùng `page-query` và một page-specific read model.
- Route interaction dùng `route-search-query` với 0–3 stops.
- Publication candidate lỗi giữ nguyên current read-model version.
- Fixture, unlicensed và unreviewed content không vào production sitemap.

## Web scope cần verify

- Homepage, City, Airport và Route Page dùng cùng server-side trust policy.
- Browser không nhận service-role key hoặc provider secret.
- Runtime DTO parser kiểm tra backend envelope.
- Canonical/noindex đúng cho base page và filtered URL.
- Loading, empty, not-found, timeout và dependency failure đều có trạng thái hữu hạn.
- Desktop và mobile không có overflow hoặc navigation tới inventory không tồn tại.
- Production build không phụ thuộc network fetch không ổn định.

## Source-state gate

Trước khi nghiệm thu phải ghi:

- Backend commit SHA.
- Web commit SHA.
- Ngày và môi trường chạy verification.
- Kết quả full backend verification.
- Kết quả lint, typecheck, unit/component tests và production build của web.
- Browser-smoke artifact cho desktop và mobile.

P0B chỉ deploy đúng cặp SHA đã nghiệm thu. Thay đổi logic sau acceptance tạo release-candidate mới.

## Remaining blockers

1. Rerun và ghi lại full backend/web evidence trên source state hiện tại.
2. Chốt server-to-server protection cho backend page/search gateway trước remote staging.
3. Có approved real API source và quyền sử dụng để chạy bounded smoke test.
4. Ghi immutable backend/web SHA pair sau khi owner cho phép commit.

P0A chưa formally accepted khi còn bất kỳ blocker nào ở trên.
