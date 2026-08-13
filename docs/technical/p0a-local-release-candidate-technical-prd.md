# PRD kỹ thuật P0A: Local Release Candidate

**PRD sản phẩm liên quan:** `docs/product/p0-staging-readiness-prd.md`  
**Kho mã:** `tripways-backend`, `tripways-web`  
**Trạng thái:** Hoàn tất local; kiến trúc chi tiết bên dưới là decision history
**Cập nhật:** 2026-08-12
**Kết quả:** Một release candidate chạy end-to-end ở local, đạt ít nhất 11/12 năng lực P0A và hoàn
tất approved-API smoke trước formal acceptance.

## 1. Kiến trúc mục tiêu

```text
Next.js Server Component
  → Next.js Route Handler hoặc server repository thống nhất
    → unified page/search backend gateway
      → service-role RPC
        → page-specific read model hoặc shared route-search projection

Mock Provider API / Approved Real API
  → privileged local ingestion Edge Function
    → service-role ingestion RPC
      → admin raw receipt tables
        → canonical country/city/airport tables
```

Implementation cuối P0A đã loại `private`, `analytics`, `ingestion_runs` và `ingestion_issues` để giữ
schema tối thiểu. Trạng thái hiện hành được mô tả tại roadmap và first-cloud-staging runbook.

Homepage, City, Airport và Route Page không được duy trì các mô hình trust khác nhau. Initial page
load dùng unified page contract và một page-specific read-model lookup; mọi tương tác route filter
dùng shared route-search contract. Web không gọi RPC bằng `SUPABASE_SERVICE_ROLE_KEY` trực tiếp từ
từng feature. Service-role chỉ tồn tại trong backend gateway hoặc server transport duy nhất được
phê duyệt.

Airport initial payload gồm identity/SEO, orientation, quick answers, arrival, departure, transport,
parking, terminals, facilities, notices, FAQ, internal links và provenance. Verified flights không
nằm trong payload editorial bất biến; web gọi shared route-search bằng scope
`{ type: "airport", key, direction: "from" | "to" }`. Scope này luôn ép `stop_count = 0` và chỉ cho
phép counterpart query/country/region, route type và operating airline ở public boundary.

## 2. Thay đổi backend bắt buộc

### 2.1 Ingestion foundation tối thiểu

Thiết kế ban đầu đề xuất các bảng private/admin sau; implementation cuối chỉ giữ hai bảng đầu:

- `admin.raw_import_batches`: batch ID, source ID, checksum, received time, source time, status.
- `admin.raw_base_data_records`: batch ID, record type, source key, payload JSONB, validation state.
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
- `ERR_PAGE_INVALID_REQUEST`
- `ERR_PAGE_NOT_FOUND`
- `ERR_PAGE_UNAVAILABLE`
- `ERR_PAGE_CONTRACT`
- `ERR_ROUTE_SEARCH_INVALID_REQUEST`
- `ERR_ROUTE_SEARCH_CONTRACT`

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
- Unified page/search boundary phải hỗ trợ cache identity gồm page/scope, locale, normalized filter
  và `data_version`.
- P0A kiểm thử được cache invalidation contract bằng version change, chưa cần CDN thật.
- Không thêm Redis.

## 7. Kiểm thử và bằng chứng

- SQL contract test cho mọi bảng ingestion mới và privilege.
- SQL E2E: valid batch, invalid batch rollback, duplicate batch, unknown-safe mapping.
- Adapter unit test cho mock và sanitized real fixture.
- Edge handler test cho auth, idempotency, input và normalized error.
- Web tests cho unified Homepage/City/Airport/Route transport, 404, error UI, metadata và noindex.
- Airport contract tests xác nhận journey payload không chứa featured inbound/outbound route hoặc
  price summary cũ; route search from/to chỉ trả verified direct service đúng direction.
- Browser smoke test desktop/mobile cho Homepage, City, Airport, Route Page, filters và map fallback.
- Full local command chạy format, lint, typecheck, Deno test, SQL E2E và production build.

## 8. Cổng nghiệm thu

- Đạt ít nhất 11/12 năng lực trong PRD sản phẩm P0.
- Năng lực chưa đạt phải phụ thuộc external approval thực sự và được ghi rõ; đạt ngưỡng local không
  tự động trở thành formal acceptance.
- Test mặc định chạy offline và xác định.
- Smoke test API thật đã phê duyệt chạy thành công nhưng không chặn CI khi mạng không có.
- Không có fixture hoặc API P0A nào indexable.
- Source state dùng cho P0B được xác định rõ.

## 9. Ngoài phạm vi

- Full production diff, approval workflow và scheduled ingestion.
- Dữ liệu route/schedule thật.
- Remote deployment.
- Production cache và monitoring.

## 10. Contract foundation cho frontend rebuild

- Xoá contract trùng lặp bằng deprecation plan; đích cuối chỉ có API versionless cho page query và
  route search.
- JSON Schema hoặc validator tương đương phải kiểm tra read model gồm identity, SEO, modules,
  internal links, commercial capability, freshness, provenance và indexability trước publication.
- Fixture cho bốn page type chứng minh frontend không cần hardcode heading, CTA, empty state hoặc
  disclosure có giá trị content.
- Request path chỉ đọc current materialized publication; không compose page bằng nhiều query động.
