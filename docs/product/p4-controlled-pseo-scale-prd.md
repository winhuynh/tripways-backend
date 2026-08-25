# PRD P4: Mở rộng pSEO có kiểm soát

**Trạng thái:** Chưa bắt đầu — chỉ bắt đầu sau P3
**Cập nhật:** 2026-08-04
**Phụ thuộc:** P3 hoàn tất và các cohort production ban đầu chứng minh được chất lượng

## 1. Mục tiêu

Mở rộng số URL pSEO theo cohort mà không tạo trang mỏng, trùng lặp, stale, thiếu quyền dữ liệu hoặc
không mang lại giá trị tìm kiếm. Quy mô URL là kết quả của quality gate, không phải mục tiêu độc lập.

## 2. Phạm vi

- Homepage discovery, City Hub direct flights, Airport departure guide và Route Page direct/indirect.
- Homepage `From + To` là một nguồn internal referral và demand signal cho Route Page canonical;
  query chưa resolve, route chưa xuất bản và kết quả date-search không thuộc inventory pSEO.
- Completeness, uniqueness, search demand, freshness, provenance và rights score theo page/version.
- Sitemap shard, rollout/rollback theo market, crawl/index monitoring và cost governance.
- Content refresh và re-review theo SLO riêng cho schedule, price estimate và editorial facts.

## 3. Yêu cầu chức năng

- Chỉ page thuộc current publication version và vượt toàn bộ gate mới xuất hiện trong sitemap.
- Page thiếu route, required module, source rights hoặc freshness tự động `noindex`.
- Canonical, hreflang và internal links được validate trước publication.
- Không URL nào được tạo hoặc đưa vào sitemap chỉ vì một lượt submit `From + To`; homepage chỉ link
  tới Route Page đã vượt publication gate.
- Rollout theo country/market cohort; mỗi cohort có holdout và rollback về publication version trước.
- Dashboard phân biệt generated, published, crawlable, crawled, indexed và organic-landing pages.

## 4. Chỉ số thành công

- Không có fixture/draft/unlicensed page trong sitemap production.
- Tỷ lệ stale/indexable page nằm trong SLO đã phê duyệt.
- Organic landing page đạt engagement/value threshold theo page type trước khi nhân rộng cohort.
- Provider và infrastructure cost nằm trong budget trên mỗi published/indexed page.

## 5. Cổng nghiệm thu

- Quality/indexability gate được kiểm thử bằng cả positive và negative fixtures.
- Sitemap shard và atomic publication rollback được diễn tập.
- Có alert cho stale spike, coverage drop, crawl waste và provider cost anomaly.
- Mỗi đợt mở rộng có quyết định go/no-go dựa trên cohort evidence.

## 6. Ngoài phạm vi

- Tạo URL chỉ để đạt số lượng.
- AI-generated editorial content không qua source/review gate.
- Index page không có unique user value hoặc không có dữ liệu đủ mới.
