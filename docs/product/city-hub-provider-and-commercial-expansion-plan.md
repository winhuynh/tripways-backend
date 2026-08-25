# City Hub provider và commercial expansion plan

**Trạng thái:** Travelpayouts test integration
**Cập nhật:** 2026-08-12

## 1. Mục tiêu sản phẩm

Tripways tạo các trang City, Airport và Route để người dùng khám phá, lọc và tìm chuyến bay phù hợp,
sau đó chuyển sang đối tác để kiểm tra giá cuối cùng và mua vé. Tripways kiếm affiliate commission
khi handoff tạo booking hợp lệ.

pSEO vẫn là giá trị cốt lõi: URL canonical, nội dung hữu ích, taxonomy, internal links và bộ lọc route
được build từ canonical/read model của Tripways. Dữ liệu provider chỉ làm giàu các module có freshness;
Tripways không bán vé, không tuyên bố inventory trực tiếp và không xây kho lịch sử fare.

Homepage dùng `From + To` để resolve entity canonical và chuyển traffic về Route Page đã xuất bản.
Nó không gọi Travelpayouts trong lúc người dùng nhập, không render kết quả live, và không tạo page từ
query. Nếu cặp chưa đủ điều kiện xuất bản, homepage trả fallback discovery thay vì suy đoán rằng route
không tồn tại.

## 2. Phân vai dữ liệu

| Thành phần                            | Nguồn hiện tại                   | Vai trò                                  |
| ------------------------------------- | -------------------------------- | ---------------------------------------- |
| Country/city/airport và mã tham chiếu | OurAirports + editorial          | Canonical identity và filter taxonomy    |
| Route/content observation ngắn hạn    | Travelpayouts/Aviasales Data API | Gợi ý route, cached fare, CTA            |
| Nội dung độc đáo                      | Tripways/editorial               | SEO value, hướng dẫn và contextual facts |
| Availability và giá cuối cùng         | Aviasales sau handoff            | Xác nhận ở booking partner               |
| Recurring schedule/live shopping      | Chưa chọn provider               | Ngoài phạm vi hiện tại                   |

AeroDataBox và AirLabs không nằm trong implementation hiện tại. Nếu cần schedule enrichment sau này,
provider mới phải qua rights review, adapter contract riêng và không thay đổi page contract.

## 3. Data lifecycle

1. Page render reference content và skeleton mà không gọi provider trong SSR.
2. Browser thật gọi `flight-route-cache`; cache hit trả ngay, cache miss mới gọi Travelpayouts.
3. Cache scope gồm origin, destination tùy chọn, market, currency và locale; scope khác không bị xoá.
4. Adapter normalize response thành `flight-content-observations.v1`; missing field giữ `null`.
5. Cron 02:20 UTC chỉ refresh scope đã có demand trong 30 ngày và chạm ngày thứ 6.
6. Mỗi row có `found_at`, `provider_expires_at`, `valid_until`; TTL không quá 7 ngày/provider expiry.
7. Raw provider payload không được lưu; empty/error dùng cooldown và giữ cache cũ còn hạn.
8. Crawler không kích hoạt provider; page pSEO vẫn hoạt động khi route cache thiếu hoặc lỗi.

Chu kỳ refresh ngày thứ 6 và provider TTL là hai khái niệm khác nhau: cron chỉ phục vụ demand gần
đây, còn `valid_until` bảo đảm Tripways không trình bày cache cũ như thông tin hiện tại.

## 4. Public contract

- Dùng `observed_amount`, không dùng `price_min/price_max` như một khoảng dự đoán.
- Luôn kèm currency, market, `found_at`, `valid_until` và disclaimer.
- Cached fare không được gọi là live fare hoặc guaranteed price.
- Không suy luận schedule, baggage, fare rules, availability hoặc self-transfer từ Data API.
- Không có observation hợp lệ thì module trả explicit unavailable/null state.
- Filter nội bộ có thể dùng observed amount để sắp xếp/lọc trong compatibility window, nhưng public
  response không xuất fabricated range.

## 5. Affiliate handoff

- Page chỉ nhận `observation_id`, không nhận destination URL tuỳ ý.
- Server xác nhận source Travelpayouts, row còn hạn và có relative affiliate path.
- Server ghép path với allowlisted host `https://www.aviasales.com`.
- CTA luôn có affiliate disclosure và nhắc giá cuối cùng được partner xác nhận.
- Có thể tắt source/capability mà không làm hỏng City Hub hoặc Route Page.

## 6. Provider portability

Provider adapter chỉ có trách nhiệm load và normalize. Publication, schema, read model, cron policy và
affiliate boundary dùng contract canonical. Đổi provider theo market/case bằng registry/configuration;
không để provider field chảy vào page DTO.

Provider mới chỉ được bật khi xác nhận đủ quyền: cache, storage ngắn hạn, public display, SEO use,
derived normalization, attribution và affiliate/deeplink. Quyền được ghi trong `admin.data_sources` và
enforced khi publish.

## 7. Rollout

- Bắt đầu với origin/market nhỏ và token server-side.
- So sánh coverage, invalid row rate, provider errors, click-through và conversion.
- Page render không gọi provider trực tiếp.
- Tăng origin scope chỉ khi request cost và content value đạt ngưỡng.
- Nếu Terms hoặc account agreement không cho phép một capability, tắt capability flag hoặc source;
  không sửa code để vượt rights gate.

## 8. Điều kiện hoàn tất

- Adapter, parser, SQL contract, cron freshness và handoff allowlist có test.
- Migration được tái dựng từ `supabase/sql_src` và local reset/E2E pass.
- Roadmap/PRD không còn coi schedule provider là dependency của commercial MVP.
- Secrets không nằm trong git/client bundle.
- Production token, Vault secrets và cron activation cần chủ sở hữu phê duyệt/deploy riêng.
