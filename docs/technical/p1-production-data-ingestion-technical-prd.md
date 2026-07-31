# PRD kỹ thuật P1: Pipeline nhập dữ liệu production

**PRD sản phẩm liên quan:** `docs/product/p1-production-data-ingestion-prd.md`  
**Phụ thuộc:** P0 hoàn tất  
**Kho mã chính:** `tripways-backend`

## 1. Mục tiêu kiến trúc

Mở rộng ingestion foundation P0 thành pipeline production có thể kiểm toán:

```text
Approved source snapshot
  → immutable raw batch
    → schema validation
      → canonical normalization
        → referential/domain validation
          → diff and anomaly gate
            → approved atomic publication
              → data version and audit record
```

## 2. Mô hình dữ liệu

### Schema `admin`

- `data_sources`: mở rộng quyền production, SEO, cache, derived data, attribution, retention.
- `ingestion_runs`: trạng thái nhận, validate, diff, approve, publish, fail.
- `ingestion_issues`: issue code, severity, bounded source reference, count/sample.
- `publish_runs`: batch, previous/new version, counts, approver/worker identity, timestamps.
- `publish_diffs`: aggregate theo entity/action; không cần lưu mọi payload duplicate.

### Schema `private`

- `raw_import_batches`: immutable source snapshot metadata.
- `raw_countries`, `raw_cities`, `raw_airports`: payload/parsed staging riêng theo entity.
- `staged_countries`, `staged_cities`, `staged_airports`: canonical candidate đã validation.

Không expose `admin` hoặc `private` qua Data API.

## 3. State machine

Trạng thái batch tối thiểu:

```text
received
  → validating
    → rejected | validated
      → diff_ready
        → approval_required | approved
          → publishing
            → published | failed
```

- Transition thuộc sở hữu RPC/PostgreSQL.
- Không cho nhảy trạng thái tùy ý từ Edge.
- Batch published là immutable.
- Retry publish cùng idempotency key trả kết quả trước đó.

## 4. Adapter OurAirports

- Download/import là thao tác explicit, không tự gọi URL tùy ý.
- Verify checksum và record source timestamp.
- Parse CSV streaming hoặc bounded memory.
- Mapping country, region, city và airport có version.
- Không dùng OpenFlights.
- Sanitized fixture đại diện cho schema thật để CI chạy offline.
- Network test tách riêng khỏi deterministic test.

## 5. Validation

### Schema validation

- Required header/version.
- Bounded string length và encoding.
- Valid ISO/IATA/ICAO shape khi có.
- Coordinate bounds.
- Supported airport type.

### Domain validation

- Country reference tồn tại.
- City identity có source lineage.
- Airport-country consistency.
- Duplicate source identity và canonical code conflict.
- Không ghi đè entity của nguồn khác nếu chưa có resolution rule.

### Anomaly gate

- Tỷ lệ reject vượt ngưỡng.
- Tỷ lệ deactivate vượt ngưỡng.
- Tổng record giảm bất thường.
- Duplicate/conflict tăng bất thường.
- Snapshot cũ hơn version đang publish.

Ngưỡng là config production được review, không lấy từ request client.

## 6. Diff và publication

- Diff theo stable source identity và canonical identity.
- Action gồm insert, update, deactivate, unchanged, reject, unresolved.
- Không hard delete canonical entity trong publication thông thường.
- Atomic transaction cập nhật normalized tables, source lineage và data version.
- Nếu bất kỳ invariant nào fail, rollback toàn bộ.
- Publication không tự bật pSEO indexability.

## 7. API vận hành

Edge operations tối thiểu:

```text
POST /functions/v1/ingestion/base-data/receive
POST /functions/v1/ingestion/base-data/validate
POST /functions/v1/ingestion/base-data/diff
POST /functions/v1/ingestion/base-data/publish
GET  /functions/v1/ingestion/base-data/runs/:id
```

Có thể gộp transport nếu vẫn giữ action allowlist và state machine. Mọi mutation yêu cầu worker
identity, idempotency, authorization và rate limit.

## 8. Security

- Raw schema không expose.
- Provider URL allowlist phía server.
- Chặn SSRF, arbitrary file path và arbitrary SQL.
- Secret trong Supabase secrets hoặc CI secret store.
- Least privilege cho worker role.
- Log chỉ chứa metadata vận hành và issue code.
- Audit được ai/worker nào yêu cầu publication.

## 9. Hiệu năng và vận hành

- Import lớn không giữ toàn bộ payload trong Edge memory.
- Heavy parse có thể chạy bằng importer script/worker; Edge chỉ orchestration.
- Index phục vụ source identity, batch state và canonical code lookup.
- Dùng `EXPLAIN` cho diff/publication query chính.
- Có retention policy cho raw batch và issue samples.
- Backup trước production publication quan trọng theo runbook.

## 10. Kiểm thử

- Parser test với schema version, encoding và malformed row.
- SQL state-machine test.
- SQL constraints/RLS/privilege test.
- Duplicate batch/idempotency test.
- Anomaly gate test.
- Atomic rollback test.
- Cross-source conflict test.
- Full local E2E: receive → validate → diff → approve → publish.
- Staging E2E với snapshot thật giới hạn.
- Performance baseline với kích thước dữ liệu đại diện.

## 11. Cổng nghiệm thu

- Một snapshot thật hoàn thành toàn bộ state machine ở staging.
- Mỗi published row có source lineage.
- Duplicate và invalid publication không thay đổi published version.
- Diff và anomaly report giải thích được thay đổi lớn.
- Không entity mới tự index.
- Security/Performance Advisor không còn finding chặn launch.
- Backup, recovery và retention runbook đã review.

## 12. Thao tác cần approval

- Phê duyệt giấy phép và quyền nguồn.
- Cấp credential/download access.
- Chạy publication trên remote production.
- Thay đổi retention hoặc xóa raw batch.
