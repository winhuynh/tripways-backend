# PRD kỹ thuật P4: Mở rộng pSEO có kiểm soát

**Phụ thuộc:** P3 hoàn tất
**Trạng thái:** Chưa bắt đầu
**Cập nhật:** 2026-08-04

## 1. Kiến trúc

P4 mở rộng publication pipeline hiện có, không tạo database hoặc CMS song song. PostgreSQL giữ
quality/indexability truth; Edge chỉ phục vụ bounded transport; Next.js render snapshot đã publish.

## 2. Quality projection

Mỗi page/version materialize:

- required-module completeness và reason codes;
- unique route/content fingerprint;
- source-rights và provenance status;
- schedule, price và editorial freshness status;
- demand/cohort eligibility;
- final `is_indexable` và `noindex_reason`.

Publication transaction fail closed khi validator lỗi. Page không đạt gate vẫn có thể phục vụ user
qua navigation nhưng không nằm trong sitemap.

## 3. Sitemap và crawl

- Sitemap đọc duy nhất current publication, shard theo page type và market.
- `lastmod` lấy từ verified content/data change, không dùng request time.
- Canonical/hreflang target phải tồn tại và tương thích locale trong cùng publication.
- Có giới hạn URL mỗi cohort và kill switch theo page type/market.

## 4. Hiệu năng và chi phí

- Benchmark publication build, read-model size, RPC p95/p99, cache hit và sitemap generation.
- Đặt budget cho provider call, storage, publication compute và bandwidth trên mỗi cohort.
- Chỉ thêm queue/search/cache service khi metric chứng minh PostgreSQL/platform primitives không đủ.

## 5. Observability

- Metrics cho generated/published/indexable/sitemap/crawled/indexed/landing page.
- Alert stale spike, coverage regression, publication failure, crawl waste và cost anomaly.
- Dashboard tách organic, advertisement và affiliate outcome để tránh tối ưu thương mại làm hỏng SEO.

## 6. Rollout và rollback

- Candidate publication được validate và so sánh diff trước promote.
- Rollout theo cohort với holdout; rollback nguyên tử về publication version trước.
- Không xoá raw/source snapshot cần cho audit trong rollback window.

## 7. Cổng nghiệm thu

- Negative fixtures chứng minh thin, duplicate, stale, unlicensed và broken-canonical pages bị loại.
- Load test đạt SLO đã phê duyệt ở kích thước cohort mục tiêu.
- Sitemap shard, cache invalidation và rollback được diễn tập end-to-end.
- Cost và quality dashboard hoạt động trước khi tăng URL limit.
