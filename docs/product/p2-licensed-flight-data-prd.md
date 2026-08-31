# PRD P2: Tuyến bay & Đồ thị Lịch trình (Route Explorer & Schedule Graph)

**Trạng thái:** Kế hoạch triển khai — Sử dụng AeroDataBox (qua API.market) & OpenFlights
**Cập nhật:** 2026-08-27
**Chủ sở hữu:** Tripways
**Kho mã:** `tripways-backend`, `tripways-web`

> Quyết định cập nhật: P2 tập trung xây dựng **Cơ sở dữ liệu đồ thị mạng lưới đường bay (Route Graph)**
> và **Lịch bay định kỳ (Schedules/Timetables)** phục vụ tính năng **Route Explorer** và ma trận trang **pSEO**
> theo mô hình của FlightConnections. Dữ liệu được nạp định kỳ (Batch Ingestion) từ **AeroDataBox (qua API.market)**
> hoặc OpenFlights vào PostgreSQL. Tầng giá vé thương mại và affiliate handoff được tách biệt hoàn toàn sang P3 (Travelpayouts).

## 1. Vấn đề

Dữ liệu định danh sân bay và thành phố từ OurAirports không đủ để trả lời người dùng có thể bay từ đâu đến đâu.
Tripways cần dữ liệu tuyến bay (Direct Routes) và lịch bay định kỳ (Operating Days, Timetables, Airlines) có bản quyền,
đủ bao phủ và cập nhật để vận hành công cụ Route Explorer và tạo hàng trăm ngàn trang pSEO chất lượng cao mà không cần
dữ liệu thời gian thực (live inventory).

## 2. Mục tiêu

Nhập và xuất bản mạng lưới tuyến bay có hướng cùng lịch bay định kỳ từ AeroDataBox (API.market) / OpenFlights,
xây dựng Route Graph Engine trong PostgreSQL để tính toán:

1. Tuyến bay thẳng (0-stop) kèm hãng khai thác và lịch bay trong tuần.
2. Các phương án nối chuyến 1–2 điểm dừng (1–2 stops) qua các Transit Hubs phổ biến (ví dụ: SIN, DOH, DXB, BKK, IST...).
3. Tự động sinh nội dung cho Airport Hub, City Hub và Route Pages (A $\to$ B) phục vụ pSEO.

## 3. Người dùng mục tiêu

- Người dùng khám phá khả năng bay từ không đến ba điểm dừng.
- Người dùng so sánh các sân bay phục vụ cùng một thành phố.
- Người dùng tìm kiếm truy cập vào hub tuyến bay của thành phố hoặc sân bay.
- Người vận hành theo dõi độ mới và quá trình xuất bản dữ liệu provider.

## 4. Điều kiện tiếp nhận provider

Chỉ bắt đầu triển khai sau khi thỏa thuận với provider trả lời rõ:

- Có được lưu dữ liệu tuyến bay và lịch bay hay không.
- Thời gian lưu và cache tối đa.
- Có được hiển thị dữ liệu trên trang SEO đã index hay không.
- Có được tạo tuyến phái sinh, số liệu tổng hợp, xếp hạng và tóm tắt hay không.
- Yêu cầu ghi nguồn.
- Yêu cầu xóa hoặc hết hạn dữ liệu.
- Giới hạn lãnh thổ, lưu lượng và phân phối lại.

Credentials và payload thô của provider luôn nằm phía máy chủ và trong vùng riêng tư.

## 5. Hành trình người dùng

### Hành trình A: Khám phá thành phố

1. Người dùng mở trang thành phố đã xuất bản.
2. Trang xác định các sân bay phục vụ và hiển thị điểm đến bay thẳng đủ điều kiện.
3. Người dùng lọc theo sân bay đi, hãng bay, quốc gia, thời lượng hoặc khung giờ khởi hành.
4. Trang ghi rõ kết quả dựa trên lịch bay đã lưu, không phải tình trạng còn chỗ hiện tại.

### Hành trình B: Khám phá sân bay

1. Người dùng mở trang sân bay đã xuất bản.
2. Người dùng chuyển giữa điểm đến chiều đi và điểm xuất phát chiều đến.
3. Người dùng lọc mẫu tuyến và xem hãng bay cùng hướng dẫn sân bay.

### Hành trình C: Khám phá hành trình có điểm dừng

1. Người dùng tìm điểm đi và điểm đến.
2. Tripways trả các mẫu lịch bay từ không đến ba điểm dừng đủ điều kiện.
3. Kết quả được xếp hạng ổn định theo số điểm dừng, thời lượng, độ tin cậy, tần suất và chất lượng nối
   chuyến.

### Hành trình D: Xử lý dữ liệu cũ hoặc không khả dụng

1. Lần nhập dữ liệu provider bị chậm hoặc thất bại.
2. Tripways giữ bộ dữ liệu hợp lệ được xuất bản gần nhất.
3. Trang hiển thị độ mới và áp dụng chính sách dữ liệu cũ/indexability mà không khẳng định sai rằng
   tuyến không tồn tại.

## 6. Yêu cầu chức năng

### 6.1 Ingestion trung lập provider

- Adapter provider chuyển payload nguồn đã phê duyệt thành đầu vào tuyến và dịch vụ định kỳ chuẩn.
- Payload thô và trường riêng của provider nằm trong vùng admin.
- Batch tái sử dụng mô hình validation, diff, idempotency và xuất bản nguyên tử của P1.
- Dữ liệu sai hoặc thiếu bản quyền không được thay thế đồ thị tuyến đã xuất bản.

### 6.2 Sự thật về tuyến bay

- Tuyến bay có hướng và giữ lineage nguồn.
- Dịch vụ định kỳ giữ thời gian hiệu lực, ngày khai thác, giờ địa phương, độ lệch ngày đến, hãng bay,
  độ tin cậy và thời gian xác minh khi có.
- Tần suất và mùa vụ bị thiếu phải giữ là chưa biết.
- Không gắn nhãn dữ liệu đã lưu là trực tiếp, còn chỗ, có thể đặt hoặc rẻ nhất.
- Tuyến nhiều chặng do Tripways ghép từ lịch bay chỉ biểu diễn khả năng nối chuyến về mặt lịch trình.
  Nó không chứng minh các chặng được bán cùng nhau, nằm trên một vé, được bảo vệ khi lỡ nối chuyến
  hoặc được chuyển hành lý đến điểm cuối.
- Không được suy luận vé chung, kết nối được bảo vệ, tự nối chuyến hoặc chuyển hành lý từ việc các
  chặng cùng hãng, cùng liên minh, có codeshare, cùng terminal hay có thời gian nối chuyến hợp lệ.
- Khi nguồn không cung cấp bằng chứng thương mại rõ ràng, các thuộc tính `single_ticket`,
  `protected_connection`, `self_transfer`, `through_baggage` và `validating_carrier` phải được coi là
  chưa biết và không được chuyển thành khẳng định trong API, UI, metadata hoặc nội dung SEO.

### 6.3 Khám phá tuyến

- Tái dựng tuyến từ không đến ba điểm dừng sau khi xuất bản thành công.
- Tương thích nối chuyến, bộ lọc, facet, phân trang và xếp hạng vẫn thuộc sở hữu cơ sở dữ liệu.
- Kết quả tìm kiếm gồm phiên bản dữ liệu, độ mới, độ tin cậy và thông báo đây là lịch bay đã lưu.
- Lỗi provider không được biến thành kết quả sai “tuyến không tồn tại”.
- Kết quả nhiều chặng phải kèm thông báo rằng đây là gợi ý dựa trên lịch bay; người dùng cần tìm
  live offer để xác nhận hành trình có được bán và điều kiện nối chuyến thực tế.

### 6.4 Xuất bản pSEO

- Phạm vi production ban đầu là một tập thành phố và sân bay giới hạn đã review.
- Airport Page chỉ được index khi có journey utility đã review (arrival, departure và transport),
  route direct đã xác minh, quyền nguồn, độ mới, metadata, định danh canonical và internal links.
- City/Route Page áp dụng route-depth gate riêng; không dùng độ sâu graph nối chuyến để thay thế
  journey-content gate của Airport Page.
- Trang trống, cũ, lịch sử, độ tin cậy thấp, chỉ dùng fixture hoặc chưa review không được index.
- Sitemap đọc trạng thái indexability tính sẵn thay vì chạy graph query toàn cục.
- Tổ hợp bộ lọc canonical về trang gốc và không được index trừ khi được tuyển chọn riêng.

### 6.5 Airport Page capability

- Airport Page là practical journey guide cho một sân bay, không phải bản sao flight-discovery của
  City Hub. Thứ tự chính là orientation/quick answers, arrival, transport, departure, sau đó mới đến
  `Verified direct flights`, parking, terminals/facilities và FAQ/provenance.
- `Verified direct flights` hỗ trợ `From airport` và `To airport`, chỉ dùng direct scheduled service
  đã publish từ provider licensed. Không hiển thị route option nhiều chặng do Tripways tính.
- Filter chỉ gồm direction, counterpart query, domestic/international, operating airline và
  counterpart country/region. Price, duration, layover, cabin, connection-airport và max-stops không
  thuộc Airport Page filter UX.
- Seasonality/frequency chỉ hiển thị khi provider contract và freshness evidence đủ tin cậy; thiếu
  dữ liệu giữ `unknown`.

### 6.6 Cache và làm mới

- Phản hồi tuyến và pSEO cache theo định danh chuẩn, bộ lọc, locale và phiên bản dữ liệu.
- Xuất bản thành công phải vô hiệu hóa cache bị ảnh hưởng hoặc chuyển sang phiên bản mới.
- TTL cache không vượt quá quyền provider hoặc chính sách độ mới.
- Không thêm Redis trừ khi lưu lượng thực tế hoặc yêu cầu invalidation không thể đáp ứng bằng cache
  nền tảng và read model cơ sở dữ liệu.

### 6.6 Nội dung

- Hướng dẫn vận hành sân bay phải có URL nguồn và thời gian xác minh.
- Nội dung biên tập phải được review trước khi index.
- Tripways phải phân biệt dữ kiện chính thức, dữ kiện tuyến từ provider, ước tính và hướng dẫn biên
  tập.

## 7. Yêu cầu phi chức năng

- Endpoint tuyến và pSEO công khai có đầu vào giới hạn, rate limit, lỗi ổn định và log an toàn.
- Một lần xuất bản cập nhật toàn bộ phiên bản graph/read model bị ảnh hưởng hoặc không cập nhật gì.
- Tìm kiếm thành phố, sân bay và tuyến phổ biến đạt mục tiêu độ trễ được xác lập qua load test
  staging.
- Cảnh báo độ mới phát hiện lần xuất bản provider bị trễ hoặc thất bại.
- Bí mật provider không đến bundle client hoặc log public.
- Trang vẫn hữu ích khi section biên tập tùy chọn không có dữ liệu.

## 8. Chỉ số thành công

- 100% tuyến và dịch vụ đã xuất bản giữ lineage nguồn đã phê duyệt.
- 100% trang indexable đạt cổng quyền, độ mới, độ tin cậy, nội dung và canonical.
- Không có bản ghi fixture nào xuất hiện trong sitemap hoặc API production.
- Ingestion định kỳ hoàn thành trong cửa sổ vận hành theo hợp đồng.
- Xuất bản thất bại giữ nguyên phiên bản dữ liệu trước đó.
- Ít nhất 95% trang chính đã review render thành công trong smoke test từ xa tự động.
- Thứ tự kết quả khám phá tuyến có tính xác định với cùng đầu vào và phiên bản dữ liệu.

## 9. Cổng nghiệm thu

P2 chỉ được nghiệm thu khi:

- Quyền provider được tài liệu hóa và phê duyệt.
- Một snapshot có bản quyền hoàn thành ingestion và xuất bản nguyên tử trên staging.
- Khám phá tuyến từ không đến ba điểm dừng hoạt động từ dữ liệu có bản quyền.
- Kho trang thành phố và sân bay production ban đầu đã được review.
- Sitemap chỉ chứa trang đủ điều kiện.
- Đã kiểm chứng độ mới, ingestion bị lỡ và rollback.
- Cache tuân thủ quyền provider.
- Trang production không đưa ra khẳng định về giá hoặc tình trạng còn chỗ trực tiếp.
- Route nhiều chặng không đưa ra khẳng định về vé chung, protected connection, self-transfer hoặc
  through baggage khi provider không cung cấp bằng chứng explicit.

## 10. Ngoài phạm vi

- Tìm kết quả theo ngày trực tiếp.
- Đặt chỗ và thanh toán.
- Hành trình nhiều điểm dừng tùy ý.
- Tự động xuất bản nội dung do AI viết.
- Index toàn cầu trước khi đo chất lượng trên kho ban đầu.
- Hành vi riêng của provider trong hợp đồng sản phẩm public.

## 11. Quản lý Rủi ro & Biện pháp kiểm soát

- **Rủi ro Thin Content / Google HCU**: Kho dữ liệu lớn tự động sinh hàng ngàn trang có thể bị Google đánh giá thấp nếu thiếu giá trị độc đáo.
  - _Kiểm soát_: Mỗi trang Route Page bắt buộc chứa các dữ liệu tính toán định lượng (khoảng cách $km$, thời gian bay, ma trận ngày bay trong tuần, so sánh bay thẳng vs nối chuyến qua Hubs). Áp dụng cổng chất lượng `noindex` đối với các trang thiếu dữ liệu lịch bay.
- **Rủi ro hiệu năng truy vấn đồ thị**: Thuật toán tìm kiếm nối chuyến 1–2 stops có thể gây chậm database.
  - _Kiểm soát_: Giới hạn đồ thị trung chuyển qua Top 50 Hubs toàn cầu; Pre-compute và Materialize các tuyến phổ biến vào bảng `flight_route_options`.
- **Rủi ro thay đổi lịch bay mùa vụ (IATA Seasonality)**: Lịch bay thực tế thay đổi theo mùa hè/mùa đông.
  - _Kiểm soát_: Cron Batch Ingestion chạy hàng tháng, kết hợp Full Sync bổ sung vào cuối tháng 3 và cuối tháng 10.
- **Rủi ro lãng phí hạn ngạch API**: Gọi API lấy thông tin sân bay làm cạn kiệt quota AeroDataBox.
  - _Kiểm soát_: Sử dụng OurAirports làm chân đế miễn phí cho danh mục Sân bay/Thành phố (P1); dành 100% quota AeroDataBox cho tuyến bay và lịch trình (P2).

## 12. AeroDataBox (API.market) Ingestion & Capability Gate

Kế hoạch đầy đủ nằm tại `docs/product/city-hub-provider-and-commercial-expansion-plan.md`.

**AeroDataBox (qua API.market)** là nguồn chính của P2 cho direct routes và flight schedules:

- **Batch Ingestion**: Chạy script định kỳ (hàng tuần hoặc hàng tháng) gọi endpoint `/airports/iata/{iata}/routes/direct` cho top 500 sân bay thương mại lớn.
- **Tiết kiệm chi phí**: Với gói $5 - $20/tháng trên API.market, toàn bộ dữ liệu được lưu vào `public.direct_flight_routes` trong Postgres để phục vụ truy vấn nội bộ tốc độ cao (<10ms).
- **Graph Traversal**: Postgres RPC tính toán các chặng nối chuyến 1–2 stops (Hub connections) dựa trên bảng chặng bay thẳng.

P2 có thể bật trên City Hub, Airport Hub và Route Pages:

- Direct destinations, map, airport/country-region/airline/duration/route-type filters.
- Operating days, flight numbers, aircraft type, operating airlines, provenance.
- City-level aggregation và route groups do Tripways tính.

P2 độc lập với dữ liệu giá vé (giá vé và affiliate CTA do P3 / Travelpayouts đảm nhiệm):

- Trang vẫn hiển thị đầy đủ bản đồ tuyến bay, hãng bay, lịch trình ngay cả khi không có giá vé hoặc Travelpayouts gặp lỗi.

## 13. Page capability sau khi có dữ liệu P2

- **City Hub**: Tập trung khám phá direct destinations theo city và các sân bay phục vụ.
- **Airport Page**: Orientation/travel guide kết hợp bảng **Direct Flight Routes** hai chiều (From & To) do hãng nào bay.
- **Route Page (A $\to$ B)**: Hiển thị các hãng bay thẳng, lịch bay trong tuần, và các phương án nối chuyến 1–2 stops qua các Hubs quốc tế lớn.
- **Travelpayouts Integration (P3)**: Gắn thêm widget/giá vé tham khảo gần nhất từ Travelpayouts Data API v3 và nút CTA chuyển tiếp an toàn (Affiliate Handoff) dẫn sang Aviasales để hoàn tất đặt vé.
