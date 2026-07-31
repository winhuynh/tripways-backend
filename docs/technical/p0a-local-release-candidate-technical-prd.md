# PRD kỹ thuật P0A: Local Release Candidate

**PRD sản phẩm liên quan:** `docs/product/p0-staging-readiness-prd.md`  
**Kho mã:** `tripways-backend`, `tripways-web`  
**Kết quả:** Một release candidate chạy end-to-end ở local và đạt ít nhất 11/12 năng lực P0A.

## 1. Kiến trúc mục tiêu

```text
Next.js Server Component
  → Next.js Route Handler hoặc server repository thống nhất
    → Supabase Edge Function public-read
      → service-role RPC
        → PostgreSQL read model

Mock Provider API / Approved Real API
  → privileged local ingestion Edge Function
    → private ingestion RPC
      → private raw/staging tables
        → canonical country/city/airport tables
```

City page và airport page không được duy trì hai mô hình trust khác nhau. Web không gọi public RPC
bằng `SUPABASE_SERVICE_ROLE_KEY` trực tiếp từ từng feature. Service-role chỉ tồn tại trong Edge
Function hoặc một server transport duy nhất được phê duyệt.

## 2. Thay đổi backend bắt buộc

### 2.1 Ingestion foundation tối thiểu

Tạo các bảng private/admin tối thiểu:

- `private.raw_import_batches`: batch ID, source ID, checksum, received time, source time, status.
- `private.raw_base_data_records`: batch ID, record type, source key, payload JSONB, validation state.
- `admin.ingestion_runs`: run ID, batch ID, action, counts, status, stable error code.
- `admin.ingestion_issues`: run ID, source key hash hoặc bounded key, issue code, severity.

P0A chưa cần approval workflow, retention scheduler hoặc full diff history.

### 2.2 Contract provider canonical

Contract đầu vào tối thiểu hỗ trợ:

- Country: ISO code, name.
- City: source ID, name, country ISO, coordinates khi có.
- Airport: source ID, name, IATA/ICAO khi có, city reference, country ISO, coordinates, type.

Giá trị chưa biết giữ là `NULL`. Không suy diễn timezone, airport-city mapping hoặc trạng thái
production khi nguồn không cung cấp.

### 2.3 Provider giả lập

- Chạy hoàn toàn offline.
- Payload có version và schema rõ ràng.
- Có dữ liệu hợp lệ cùng trường hợp duplicate, missing required field, invalid coordinate và
  unresolved reference.
- Fixture payload nằm ngoài migration và schema source.
- Adapter mock sử dụng cùng canonical contract mà adapter thật sẽ dùng.

### 2.4 Smoke test API thật

- API được cấu hình qua biến môi trường.
- Không chạy trong test suite mặc định.
- Giới hạn response bằng allowlist ID, page size nhỏ hoặc bounded record count.
- Payload thật được sanitize thành fixture offline; không lưu secret, header hoặc dữ liệu bị cấm.
- Source trong P0A có `environment_scope = development`, `production_allowed = false` và
  `seo_allowed = false`.

### 2.5 Publication local tối thiểu

- Batch hợp lệ được publish bằng một RPC transaction.
- Idempotency dựa trên source + checksum hoặc idempotency key.
- Invalid batch không thay đổi canonical data.
- Partial record rejection phải được đếm rõ; chế độ atomic hoặc partial-accept phải được chọn rõ cho
  từng run. Mặc định P0A dùng atomic batch để chứng minh rollback.
- Publication không tự động bật indexability.

## 3. Thay đổi web bắt buộc

### 3.1 Data boundary thống nhất

- City và airport repository sử dụng cùng kiểu server-only environment và transport policy.
- External response luôn qua runtime DTO parser.
- Timeout hoặc invalid envelope map thành stable domain error.
- Missing identity map thành 404; dependency failure map thành bounded error UI.

### 3.2 Homepage inventory

- Homepage read model chỉ chứa link tới city và airport có dữ liệu local hoàn chỉnh.
- Link placeholder, newsletter không hoạt động và legal anchor giả phải bị xóa, disable hoặc ghi rõ
  preview.
- Route-map failure có fallback hữu ích.

### 3.3 Metadata

- Fixture và dữ liệu API P0A luôn `noindex`.
- Filter URL canonical về base page.
- Metadata failure không tạo title lặp hoặc làm page treo.
- Thêm robots và sitemap behavior local/staging rõ ràng.

### 3.4 Build reproducibility

- Font không được làm production build phụ thuộc vào một network fetch không ổn định.
- `.env.example` mô tả mọi biến cần thiết bằng placeholder.
- Environment validation fail fast với stable setup error, không log secret.

## 4. API và lỗi

Endpoint ingestion local tối thiểu:

```text
POST /functions/v1/ingestion/base-data
```

Request yêu cầu:

- Worker secret hoặc verified local operator identity.
- `Idempotency-Key`.
- Source code.
- Provider mode `fixture` hoặc `approved_api`.

Mã lỗi tối thiểu:

- `ERR_INGESTION_UNAUTHORIZED`
- `ERR_INGESTION_INVALID_REQUEST`
- `ERR_INGESTION_SOURCE_NOT_ALLOWED`
- `ERR_INGESTION_BATCH_DUPLICATE`
- `ERR_INGESTION_VALIDATION_FAILED`
- `ERR_INGESTION_PUBLISH_FAILED`
- `ERR_CITY_PAGE_UNAVAILABLE`
- `ERR_AIRPORT_PAGE_UNAVAILABLE`

## 5. Bảo mật

- Không nhận arbitrary provider URL từ request.
- Provider base URL và source allowlist do server cấu hình.
- Rate limit ingestion theo worker và IP đã normalize/hash.
- Raw payload không expose qua Data API.
- Public client không có write privilege trên canonical tables.
- Service-role không xuất hiện trong `NEXT_PUBLIC_*`.
- Log không chứa raw payload, full IP, bearer token hoặc key.

## 6. Cache

- Local có thể dùng cache bypass để dễ kiểm thử ingestion.
- City và airport repository phải hỗ trợ cache identity gồm locale, entity identity, filter và
  `data_version`.
- P0A kiểm thử được cache invalidation contract bằng version change, chưa cần CDN thật.
- Không thêm Redis.

## 7. Kiểm thử và bằng chứng

- SQL contract test cho mọi bảng ingestion mới và privilege.
- SQL E2E: valid batch, invalid batch rollback, duplicate batch, unknown-safe mapping.
- Adapter unit test cho mock và sanitized real fixture.
- Edge handler test cho auth, idempotency, input và normalized error.
- Web tests cho city/airport transport thống nhất, 404, error UI, metadata và noindex.
- Browser smoke test desktop/mobile cho homepage, city, airport, filters và map fallback.
- Full local command chạy format, lint, typecheck, Deno test, SQL E2E và production build.

## 8. Cổng nghiệm thu

- Đạt ít nhất 11/12 năng lực trong PRD sản phẩm P0.
- Năng lực chưa đạt phải phụ thuộc cloud thực sự và được ghi rõ.
- Test mặc định chạy offline và xác định.
- Smoke test API thật đã phê duyệt chạy thành công nhưng không chặn CI khi mạng không có.
- Không có fixture hoặc API P0A nào indexable.
- Source state dùng cho P0B được xác định rõ.

## 9. Ngoài phạm vi

- Full production diff, approval workflow và scheduled ingestion.
- Dữ liệu route/schedule thật.
- Remote deployment.
- Production cache và monitoring.
