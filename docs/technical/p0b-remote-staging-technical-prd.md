# PRD kỹ thuật P0B: Remote Staging

**PRD sản phẩm liên quan:** `docs/product/p0-staging-readiness-prd.md`  
**Phụ thuộc:** P0A đã nghiệm thu  
**Kết quả:** Release candidate P0A chạy ổn định trên staging riêng tư.

## 1. Nguyên tắc

P0B không phát triển logic sản phẩm mới. Mọi lỗi logic phát hiện trên staging phải được tái hiện,
sửa và kiểm thử ở local, sau đó tạo source state mới để redeploy.

## 2. Kiến trúc staging

```text
Cloudflare Access hoặc access boundary tương đương
  → Cloudflare Workers + OpenNext
    → Next.js SSR / Route Handlers
      → Supabase staging Edge Functions
        → Supabase staging Postgres
```

Không dùng static export hoặc Cloudflare Pages cho ứng dụng full-stack hiện tại.

## 3. Tách biệt môi trường

- Supabase staging project riêng.
- Cloudflare project/environment riêng.
- Staging URL hoặc subdomain riêng.
- Service-role, anon/publishable key và provider credential riêng.
- Không dùng production database, domain hoặc secrets.
- Preview build không được thừa hưởng production secrets.

## 4. Database deployment

- Schema được dựng từ migration trong kho mã.
- Seed staging chỉ chứa fixture/sanitized snapshot được cho phép.
- Không sửa schema thủ công qua Dashboard.
- Migration list local và remote phải khớp.
- Có pre-deploy backup hoặc phương án recreate toàn bộ staging.

## 5. Edge deployment

- Deploy health, city page, route discovery, airport/public-read boundary và ingestion foundation cần
  cho staging.
- Cấu hình `verify_jwt` đúng theo endpoint.
- Public reads không dùng JWT người dùng nhưng vẫn có bounded input và rate limit.
- Privileged ingestion yêu cầu secret/worker identity.
- Kiểm tra trực tiếp health và từng Edge endpoint sau deploy.

## 6. Web deployment

- Dùng OpenNext adapter và Cloudflare Workers.
- Server-only variables được cấu hình ở runtime/build theo yêu cầu adapter.
- `NEXT_PUBLIC_SITE_URL` trỏ đúng staging origin.
- Không expose source map production nếu không cần.
- Cấu hình security headers tối thiểu: HSTS khi HTTPS ổn định, `nosniff`, referrer policy,
  permissions policy và clickjacking protection.

## 7. Noindex và access control

- Mọi response staging có robots policy chặn index.
- `robots.txt` chặn crawler.
- Sitemap staging rỗng hoặc chỉ phục vụ kiểm thử có bảo vệ và vẫn `noindex`.
- Dùng Cloudflare Access hoặc boundary tương đương cho người review.
- Không dựa chỉ vào URL khó đoán nếu staging chứa secret-bearing behavior.

## 8. Cache staging

- Kiểm chứng Next.js revalidation và cache header trên response thật.
- Cache key gồm entity, locale, filter và data version.
- Error response và authenticated/privileged response không cache.
- Publication/version change tạo cache miss hoặc invalidation theo contract.
- Ghi nhận `HIT`, `MISS` hoặc `BYPASS` trong metadata/log khi phù hợp.

## 9. Observability

- Structured log có request ID xuyên Next.js, Edge và RPC khi có thể.
- Health check không phụ thuộc dữ liệu fixture cụ thể.
- Theo dõi 5xx, timeout, Edge invocation failure và latency.
- Không log secrets hoặc raw payload.
- Có runbook xác định nơi xem log và cách liên kết request.

## 10. CI/CD

- Pull request chạy quality suite nhưng không tự động đụng production.
- Staging deploy chỉ từ branch/source state đã phê duyệt.
- Migration deploy trước Edge/Web theo dependency.
- Post-deploy smoke test là bắt buộc.
- Deploy thất bại phải dừng pipeline và không đánh dấu release thành công.

## 11. Smoke test remote

Kiểm tra tối thiểu:

- Homepage 200 và không có link hỏng đã biết.
- City page 200, dữ liệu hợp đồng đúng.
- Airport page 200, không lỗi setup key.
- Filter request trả kết quả hoặc empty state đúng.
- Route map hoặc fallback hoạt động.
- Trang không tồn tại trả 404.
- Dependency failure trả bounded error.
- Robots/noindex đúng.
- Client bundle không chứa service-role.
- Health và ingestion authorization boundary đúng.

Chạy ba lần liên tiếp trên desktop và mobile viewport chính.

## 12. Rollback

- Web và Edge có thể rollback về version trước.
- Migration breaking change không được đưa vào P0B.
- Nếu migration không tương thích ngược là bắt buộc, phải có kế hoạch expand/contract riêng.
- Staging có thể recreate hoàn toàn từ repo và secrets được cấp lại.

## 13. Cổng nghiệm thu

- Đúng source state P0A được deploy.
- Ba lượt smoke test liên tiếp pass.
- Khôngindex và access control đã kiểm chứng từ ngoài.
- Cache/version behavior đúng.
- Không còn critical/high security issue.
- Có deployment, observability và rollback runbook.

## 14. Thao tác cần approval

- Tạo/link Supabase project.
- Tạo Cloudflare Worker/project.
- Cấu hình DNS/subdomain.
- Thiết lập secrets và Cloudflare Access.
- Deploy remote hoặc thay đổi quyền truy cập.
