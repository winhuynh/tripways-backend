# Lộ trình sản phẩm MVP Tripways

**Trạng thái:** Đang thực hiện — phase hiện tại P0A
**Cập nhật:** 2026-08-05
**Phạm vi:** `tripways-backend` và `tripways-web`

## 1. Định hướng sản phẩm

Tripways là sản phẩm dữ liệu đồ thị du lịch và khám phá chuyến bay, lấy hàng không làm trọng tâm
đầu tiên. Sản phẩm giúp người dùng hiểu những tuyến bay từ không đến ba điểm dừng nào thường tồn tại
giữa các thành phố và sân bay, sau đó từng bước mở rộng sang tìm kiếm chuyến bay theo ngày và
chuyển tiếp an toàn tới đối tác liên kết.

Tripways không phát hành vé, xử lý thanh toán đặt chỗ, quản lý hủy vé hoặc khẳng định tình trạng
còn chỗ theo thời gian thực dựa trên dữ liệu lịch bay đã lưu.

## 2. Nền tảng hiện tại

Nguyên mẫu cục bộ hiện có:

- Các bảng quốc gia, thành phố, sân bay, hãng bay, tuyến bay và dịch vụ bay định kỳ đã được chuẩn
  hóa.
- Khám phá tuyến bay từ không đến ba điểm dừng bằng dữ liệu mẫu phát triển có tính xác định.
- Typed content/FAQ schema và mô hình đọc pSEO đã materialize cho Homepage, City, Airport và Route.
- Hai contract versionless `rpc_get_page` và `rpc_search_routes`; các public RPC pSEO trùng lặp/legacy
  đã được xoá khỏi source đang hoạt động.
- Contract và primitive Next.js từ nguyên mẫu cũ được giữ lại để phục vụ rebuild; các page cũ đã
  được dọn khỏi frontend.
- RLS, phân quyền tối thiểu, sử dụng khóa `service-role` phía máy chủ và kiểm thử hợp đồng.

Nguyên mẫu hiện chưa có:

- Môi trường staging từ xa ổn định.
- Pipeline nhập dữ liệu production hoặc nguồn dữ liệu production đã được phê duyệt.
- Nhà cung cấp dữ liệu tuyến bay hoặc lịch bay có bản quyền.
- Kết quả chuyến bay và giá theo ngày.
- Chuyển hướng liên kết và phân tích hành vi sản phẩm.
- Xuất bản sitemap production hoặc quy trình ra mắt production.

## 3. Các giai đoạn bàn giao

| Giai đoạn | Trạng thái         | Kết quả sản phẩm                                                                     | Điều kiện hoàn tất                                                                       |
| --------- | ------------------ | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| P0A       | **Đang thực hiện** | Local release candidate hoàn thành phần lớn hành vi sản phẩm và pipeline dữ liệu nhỏ | Toàn bộ hành vi không phụ thuộc cloud chạy end-to-end ở local và đạt cổng chất lượng P0A |
| P0B       | Chưa bắt đầu       | Sản phẩm staging ổn định, riêng tư và `noindex`                                      | Cùng release candidate hoạt động từ xa; chỉ còn khác biệt hạ tầng, bí mật và vận hành    |
| P1        | Chưa bắt đầu       | Có thể nhập và kiểm duyệt dữ liệu nền thật một cách an toàn                          | Dữ liệu quốc gia, thành phố và sân bay thật được xuất bản qua pipeline có thể kiểm toán  |
| P2        | Chưa bắt đầu       | Dữ liệu tuyến bay và lịch bay có bản quyền vận hành lớp khám phá đáng tin cậy        | Khám phá tuyến bay và pSEO sử dụng dữ liệu production mới, có bản quyền                  |
| P3        | Chưa bắt đầu       | Người dùng có thể tìm chuyến bay theo ngày; quảng cáo và affiliate hoạt động an toàn | MVP production đáp ứng cổng thương mại, bảo mật, disclosure, phân tích và độ tin cậy     |
| P4        | Chưa bắt đầu       | Mở rộng pSEO có kiểm soát từ tập thị trường đã chứng minh giá trị                    | Coverage, quality, indexability, cost và freshness gate hoạt động ở quy mô production    |

Một số schema, contract và read model phục vụ P1–P3 có thể được chuẩn bị trong P0A để tránh thiết kế
lại. Những foundation đó không làm thay đổi trạng thái phase và không phải bằng chứng nghiệm thu.

Không giai đoạn nào được phụ thuộc vào hành vi chưa hoàn thành của giai đoạn sau. Mỗi giai đoạn phải
vẫn hữu ích và có thể kiểm thử độc lập khi các giai đoạn sau chưa tồn tại.

P0 gồm hai cổng tuần tự. P0A phải hoàn thành tối thiểu 90% danh mục hành vi P0 có thể chạy độc lập
với cloud. P0B không phải một vòng phát triển tính năng mới; nhiệm vụ chính là xác nhận cùng release
candidate trên hạ tầng từ xa. P0 chỉ hoàn tất khi cả P0A và P0B được nghiệm thu.

## 4. Nguyên tắc sản phẩm xuyên suốt

1. **Quyền dữ liệu đi trước tăng trưởng:** Không xuất bản dữ liệu cho tới khi quyền dùng cho
   production, SEO, bộ nhớ đệm và dữ liệu phái sinh được ghi nhận và phê duyệt.
2. **Khẳng định an toàn:** Lịch bay đã lưu chỉ mô tả mẫu tuyến định kỳ, không mô tả số ghế, giá hay
   khả năng khai thác được đảm bảo ở thời điểm hiện tại.
3. **Cô lập dữ liệu mẫu:** Dữ liệu mẫu phát triển luôn tách khỏi production và không được lập chỉ mục.
4. **Ra mắt từng bước:** Staging đi trước production; kho dữ liệu giới hạn đi trước quy mô toàn cầu.
5. **Minh bạch nguồn:** Dữ liệu công khai phải có nguồn, độ tin cậy, độ mới và phiên bản dữ liệu.
6. **Tin cậy phía máy chủ:** Dữ liệu từ trình duyệt không được quyết định phân quyền, giá từ nhà cung
   cấp, đích liên kết, trạng thái xuất bản hoặc khả năng lập chỉ mục.
7. **Hạ tầng dựa trên đo lường:** Ưu tiên bộ nhớ đệm HTTP và tính năng nền tảng trước khi thêm dịch
   vụ cache hoặc hàng đợi.
8. **Backend sở hữu content pSEO:** Heading, mô tả, FAQ, CTA có ý nghĩa, empty state, disclosure,
   internal link và cấu hình module công khai phải đến từ read model đã xuất bản; frontend không
   chứa content thay thế có thể tạo ra hàng triệu trang giống nhau.
9. **Contract không mang hậu tố phiên bản:** Mỗi capability chỉ có một contract canonical đang hoạt
   động. Migration contract dùng compatibility window và deprecation plan, không duy trì lâu dài
   các cặp `rpc_*` và `rpc_*_v2` song song.

## 5. Thước đo thành công tổng thể

Lộ trình MVP thành công khi:

- Người dùng có thể mở trang thành phố hoặc sân bay đã xuất bản và hiểu các mẫu tuyến bay thẳng hiện
  có.
- Người dùng có thể tìm hành trình theo ngày và nhận kết quả đã chuẩn hóa từ nhà cung cấp.
- Người dùng có thể chuyển tới đối tác liên kết trong danh sách cho phép mà Tripways không nhận URL
  chuyển hướng tùy ý.
- Mọi khẳng định công khai đều truy vết được về nguồn và trạng thái độ mới đã phê duyệt.
- Nhóm sản phẩm đo được lượt dùng trang, lượt tìm kiếm, không có kết quả, lỗi nhà cung cấp và lượt rời
  qua liên kết mà không lưu dữ liệu hành khách không cần thiết.
- Một lần nhập dữ liệu hoặc gọi nhà cung cấp thất bại không làm hỏng đồ thị tuyến bay đã xuất bản gần
  nhất.

## 6. Ngoài phạm vi toàn bộ MVP

- Phát hành vé, thu tiền, hoàn tiền, hủy vé và hỗ trợ khách hàng.
- Lập hành trình bằng AI.
- Đánh giá do người dùng tạo và nội dung cộng đồng.
- Tàu hỏa, xe buýt, phà, du thuyền và các phương thức vận tải khác.
- Hành trình nhiều thành phố hoặc có hơn ba điểm nối chuyến.
- Trải nghiệm thành viên trả phí, gói đăng ký và tính năng cao cấp. Auth/account-security foundation
  có thể tồn tại trước nhưng không đồng nghĩa sản phẩm membership đã nằm trong MVP.
- Redis, hàng đợi bền vững hoặc công cụ tìm kiếm riêng khi chưa có nhu cầu đã đo được.

## 7. Quản trị

- Nghiệm thu sản phẩm dựa trên điều kiện hoàn tất trong PRD của từng giai đoạn.
- Triển khai kỹ thuật tuân theo kế hoạch triển khai tương ứng.
- Mọi thao tác triển khai production, thay đổi tên miền, ký hợp đồng dữ liệu, thao tác cơ sở dữ liệu
  từ xa hoặc cấp bí mật đều cần chủ sở hữu phê duyệt rõ ràng.
- Thay đổi phạm vi đáng kể phải cập nhật PRD tương ứng trước khi triển khai.

## 8. Kế hoạch mở rộng City Hub đã ghi nhận

Kế hoạch chi tiết nằm tại `docs/product/city-hub-provider-and-commercial-expansion-plan.md` và đang
ở trạng thái chưa triển khai.

- P0A/P0B giữ provider-neutral contract, fixture và staging `noindex`; không tích hợp AirLabs thật.
- P1 hoàn thiện dữ liệu nền, quyền nguồn và city-airport/region taxonomy; không nhập route/schedule.
- P2 đánh giá AirLabs bằng POC và chỉ bật route/schedule pSEO sau khi quyền SEO, cache, snapshot và
  derived data được phê duyệt.
- P3 chọn price/live-search/affiliate provider; AirLabs không thay thế flight-shopping provider.
- Module giá, tháng khởi hành và affiliate luôn optional; City Hub core không phụ thuộc chúng.

## 9. Bổ sung phạm vi pSEO theo phase

### P0A/P0B — Khoá contract và rebuild foundation

- Dọn frontend cũ; chỉ giữ app shell, Terms và các primitive dùng lại được cho tới khi contract mới
  có test.
- Chọn một public page contract và một route-search contract không có hậu tố `_v2`.
- Định nghĩa page read model cho Homepage, City Hub, Airport và Route gồm module order, UX copy,
  CTA, empty state, metadata, freshness, provenance và indexability.
- Khoá Airport Page theo intent journey-first: orientation, arrival, transport, departure rồi mới
  đến verified direct flights hai chiều; không tái sử dụng featured-route payload cũ.
- Fixture chỉ chứng minh contract và luôn `noindex`; không được xem là content coverage production.

### P1 — Content foundation và dữ liệu tham chiếu production

- Nhập country, region, city, airport, timezone và city-airport grouping có quyền sử dụng rõ ràng.
- Xây workflow biên tập/kiểm duyệt cho airport orientation, arrival/departure steps, directional
  transport, parking, terminal/facility, lounge, notice, FAQ và internal link.
- Tính content completeness theo page type; page thiếu dữ liệu không được tự động index.

### P2 — Route, schedule và estimated fare có bản quyền

- Xuất bản direct route cho City Hub và verified direct flights from/to cho Airport Page; Route Page
  hỗ trợ cả direct lẫn connecting options.
- City Hub có thể hỗ trợ departure airport, geography, duration và estimated-price filters. Airport
  chỉ hỗ trợ counterpart query/geography, domestic/international và operating airline; không có
  connection, duration hoặc price filter.
- Estimated fare là observation/range có trip type, source, confidence, sample window và expiry; không
  được mô tả như live offer.

### P3 — Advertisement, affiliate và live search

- Advertisement slot, sponsored module, affiliate offer, CTA và disclosure được cấu hình từ backend.
- Commercial module optional, có capability gate và kill switch; thiếu partner không làm hỏng page.
- Tách rõ estimated fare của pSEO khỏi live offer theo ngày và affiliate handoff.
- Airport commercial module không thay thế arrival/transport/departure; live-search chỉ prefill từ
  verified direct row người dùng đã chọn.

### P4 — Mở rộng pSEO có kiểm soát

- Chỉ mở rộng page count khi query demand, unique value, content completeness và freshness đạt ngưỡng.
- Publication gate tự động `noindex` page mỏng, trùng lặp, stale, thiếu quyền nguồn hoặc không có route.
- Theo dõi crawl/index coverage, organic landing quality, filter usage, affiliate conversion, ad impact,
  provider cost và stale-data SLO theo page cohort.
- Rollout theo country/market cohort và có rollback về publication version gần nhất.
