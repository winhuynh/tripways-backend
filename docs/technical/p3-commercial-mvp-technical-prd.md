# PRD kỹ thuật P3: Commercial MVP

**PRD sản phẩm liên quan:** `docs/product/p3-commercial-mvp-prd.md`  
**Phụ thuộc:** P2 hoàn tất, live-search và affiliate agreements được phê duyệt
**Trạng thái:** Chưa bắt đầu
**Cập nhật:** 2026-08-04

`route_price_estimates` và price ingestion foundation hiện tại không phải offer search, search state,
affiliate handoff hoặc P3 acceptance. Live offer luôn là short-lived provider result với expiry và
server-owned outbound reference riêng.

## 1. Kiến trúc

```text
Next.js search UI
  → Next.js live-search Route Handler
    → live-search orchestration service
      → provider adapter
        → normalized short-lived offers

Offer selection
  → outbound token service
    → allowlisted affiliate target
      → analytics event
        → safe redirect
```

Route graph và live offers là hai source of truth khác nhau. Provider live failure không thay đổi
route graph.

## 2. Search request contract

Input canonical:

- Origin và destination.
- Trip type được hỗ trợ.
- Departure và return date khi có.
- Adults, children, infants với bounds.
- Cabin.
- Locale và currency preference.

Runtime validation từ chối unknown field, invalid date range, same origin/destination và passenger
combination không hỗ trợ.

## 3. Search state

Private operational state:

- Opaque Tripways search ID.
- Normalized request fingerprint.
- Provider operation reference.
- Status: created, running, completed, no_results, failed, expired.
- Created/updated/expires timestamps.
- Sanitized error code.

Không lưu full passenger identity nếu provider không bắt buộc. Không expose provider token.

## 4. Provider adapter

Interface hỗ trợ:

- Start search.
- Poll search khi cần.
- Normalize result.
- Map provider error.
- Resolve/validate affiliate deeplink.

Adapter có deterministic fixture cho completed, polling, no-result, timeout, malformed offer và
provider failure.

## 5. Offer normalization

Offer canonical gồm:

- Offer ID opaque.
- Provider ID.
- Itinerary và ordered legs.
- Operating/marketing airline.
- Airport/time/duration/stops.
- Cabin và fare attributes khi có.
- Price amount và currency.
- Baggage nullable.
- Offer expiry.
- Server-owned affiliate reference.

Với itinerary nhiều leg, canonical offer còn có:

```text
ticketing_type: single_ticket | separate_tickets | unknown
ticket_count: integer | null
validating_carrier: airline_reference | null
connection_type: protected | self_transfer | unknown
through_baggage: true | false | unknown
commercial_evidence: provider_explicit | unavailable
```

Quy tắc normalization:

- Chỉ dùng `provider_explicit` khi adapter ánh xạ từ field provider đã được tài liệu hóa và contract
  test; không dùng inference từ route graph, airline, alliance, codeshare, terminal hoặc layover.
- `ticket_count` và `validating_carrier` là `null` khi provider không trả hoặc semantics chưa rõ.
- `unknown` không được normalize thành `false`. Không có bằng chứng self-transfer không đồng nghĩa
  connection được bảo vệ, và ngược lại.
- Nếu provider chỉ trả itinerary/price mà không trả connection semantics, offer vẫn giữ toàn bộ field
  trên ở trạng thái unknown/unavailable và public response kèm warning ổn định.
- AirLabs route, schedule, codeshare hoặc flight-status payload không được dùng làm commercial
  evidence cho các field này. AirLabs có thể enrich operating/marketing flight facts, nhưng không
  thay thế live shopping/offer provider.
- Provider adapter phải khai báo capability matrix theo version. Field ngoài capability đã phê duyệt
  bị bỏ qua hoặc giữ unknown cho đến khi mapping được review.

Client không gửi giá để tạo redirect hoặc analytics authoritative event.

## 6. API

```text
POST /api/live-flights/search
GET  /api/live-flights/search/:searchId
POST /api/outbound/token
GET  /api/outbound/:token
POST /api/events
```

- POST search có rate limit, idempotency/fingerprint và request bound.
- GET search chỉ trả normalized state/result.
- Outbound token endpoint nhận offer reference, không nhận arbitrary URL.
- Redirect endpoint validate expiry, signature/opaque lookup và domain allowlist.
- Events chỉ nhận allowlisted schema.

## 7. Rate limit và cost control

- Kết hợp IP hash và user ID khi có.
- Separate quotas cho search start, poll, outbound token và events.
- Poll interval do server response hướng dẫn.
- Provider concurrency cap.
- Timeout và circuit breaker.
- Billing alert và hard cap khi provider hỗ trợ.
- Kill switch theo provider và toàn bộ live search.

## 8. Cache và expiry

- Route/pSEO tiếp tục cache theo P2.
- Search request không dùng durable public cache.
- Offer cache TTL không vượt provider terms hoặc `expires_at`.
- Expired offer không tạo outbound token.
- Poll response có no-store hoặc private short TTL phù hợp.
- Không thêm Redis trừ khi polling/concurrency đã chứng minh Postgres/native cache không đủ.

## 9. Affiliate security

- Partner domain allowlist lưu server-side.
- Normalize và validate scheme HTTPS.
- Chặn open redirect, protocol-relative URL, encoded hostname confusion và subdomain spoofing.
- Token short-lived, tamper-resistant và single-purpose.
- Log click bằng opaque identifiers.
- Redirect failure không trả target nội bộ hoặc provider secret.

## 10. Analytics

Schema `analytics` không expose qua Data API.

Event allowlist:

- `PAGE_VIEW`
- `SEARCH_STARTED`
- `SEARCH_COMPLETED`
- `SEARCH_NO_RESULTS`
- `SEARCH_FAILED`
- `FILTER_APPLIED`
- `OFFER_SELECTED`
- `AFFILIATE_REDIRECTED`

Payload bounded, versioned và không chứa raw passenger/provider payload. Event ingestion có rate
limit và sampling policy nếu cần.

## 11. Web UX

- Search form truy cập được bằng bàn phím.
- State UI: validating, starting, polling, completed, no-result, timeout, failed, expired.
- Filter live offer không nhầm với stored route filters.
- Price có currency và thời điểm/expiry context.
- Hiển thị disclosure booking với partner.
- Hiển thị rõ “protected connection”, “self-transfer” hoặc “separate tickets” chỉ khi
  `commercial_evidence=provider_explicit`; nếu không, hiển thị “Chưa có thông tin về bảo vệ nối
  chuyến” và hướng người dùng kiểm tra điều kiện trên trang đối tác.
- Không dùng màu sắc, icon hoặc copy ngầm truyền đạt connection an toàn khi trạng thái là `unknown`.
- Legal, privacy, affiliate disclosure và attribution có route thật, không dùng anchor placeholder.

## 12. Observability

- Correlation ID xuyên request, search operation, provider call và redirect.
- Metrics: start/completion/no-result/error, latency p50/p95, provider errors, offer selection,
  redirect, cost.
- Alert provider error spike, timeout spike, cost threshold và redirect rejection.
- Dashboard không hiển thị secret hoặc raw passenger data.

## 13. Kiểm thử

- Search input matrix.
- Provider adapter normalization, polling, timeout và error mapping.
- Capability-matrix tests cho từng provider/version và fixtures có/không có commercial connection
  fields.
- Tests chống suy luận từ AirLabs/codeshare/airline/alliance/layover và phân biệt `unknown` với
  `false`.
- Contract/UI tests đảm bảo unknown connection hiển thị warning, không over-promise.
- Offer deduplication và expiry.
- Rate-limit/concurrency/cost guard tests.
- Affiliate allowlist, tampering, expiry và open-redirect tests.
- Analytics allowlist/size/privacy tests.
- Full E2E: discovery page → dated search → completed offers → token → redirect event.
- Failure E2E: provider down nhưng discovery page vẫn hoạt động.
- Load and abuse test trên staging.

## 14. Production hardening

- Environment isolation và secret rotation runbook.
- HTTPS, security headers và no debug leakage.
- Database backup/PITR theo yêu cầu vận hành.
- Incident owner và kill-switch procedure.
- Bounded launch cohort/markets.
- Production domain chỉ gắn sau launch review.

## 15. Cổng nghiệm thu

- Provider agreements được phê duyệt.
- Search/poll/normalize/redirect E2E pass ở staging.
- Không open redirect hoặc client-controlled price.
- Rate/cost/timeout/kill-switch đã kiểm chứng.
- Analytics và privacy retention được review.
- Monitoring, backup, rollback và incident runbook hoàn chỉnh.
- Legal và affiliate disclosure đã publish.
- Mỗi provider/version có capability matrix và test xác nhận commercial connection field chỉ dùng
  `provider_explicit`; trường thiếu hiển thị warning và giữ `unknown`/`unavailable` xuyên suốt.

## 16. Thao tác cần approval

- Cấp provider và affiliate credentials.
- Thiết lập billing/cost cap.
- Production deploy và domain/DNS.
- Bật analytics production.
- Mở traffic cohort hoặc tăng rate limits.

## 17. Advertisement và affiliate read model

- Schema placement dùng stable slot key, page/module adjacency, locale, format, eligibility, partner,
  campaign window, disclosure và enabled state.
- Publication composer chỉ đưa commercial module vào payload khi rights/capability/campaign hợp lệ.
- Affiliate redirect nhận signed offer/partner identifier, resolve server-side và chặn open redirect.
- Organic ranking/read model được tính độc lập; sponsored module không được chen vào organic array
  hoặc làm thay đổi structured data SEO.
