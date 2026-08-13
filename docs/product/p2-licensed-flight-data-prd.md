# PRD P2: Dữ liệu chuyến bay có bản quyền

**Trạng thái:** Hoãn schedule-provider scope; commercial content đi theo Travelpayouts plan
**Cập nhật:** 2026-08-12
**Chủ sở hữu:** Tripways
**Kho mã:** `tripways-backend`, `tripways-web`

> Quyết định hiện hành: P2 không tích hợp AirLabs/AeroDataBox. Các phần schedule-provider bên dưới
> được giữ làm yêu cầu tương lai, không phải dependency để ra mắt pSEO/affiliate MVP. Contract hiện
> tại là short-lived Travelpayouts content observations theo kế hoạch City Hub.

## 1. Vấn đề

Dữ liệu định danh sân bay và thành phố không đủ để trả lời người dùng thường có thể bay đi đâu.
Tripways cần dữ liệu tuyến bay và lịch bay định kỳ có bản quyền, đủ mới và đủ quyền để vận hành khám
phá tuyến và pSEO mà không mô tả lịch bay đã lưu như tình trạng còn chỗ trực tiếp.

Dữ liệu tuyến mẫu và các read-model foundation 0–3 stops chứng minh được hành vi kỹ thuật nhưng không
thể công bố như sự thật production và không có nghĩa P2 đã bắt đầu.

## 2. Mục tiêu

Nhập và xuất bản tuyến bay có hướng cùng dịch vụ bay định kỳ có bản quyền, tái dựng read model tuyến
từ không đến ba điểm dừng, đồng thời cung cấp Homepage, City, Airport và Route Page đáng tin cậy với độ
mới, độ tin cậy và điều kiện lập chỉ mục dựa trên nguồn rõ ràng.

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

## 11. Rủi ro

- Quyền provider có thể cấm SEO, TTL cache dài hoặc graph tuyến phái sinh.
- Snapshot lịch bay có thể khác hoạt động thực tế theo ngày.
- Tuyến nhiều điểm dừng có thể tương thích về lý thuyết nhưng không bán được về thương mại.
- Dữ liệu codeshare có thể bị hiểu nhầm thành vé chung hoặc kết nối được bảo vệ, dù codeshare chỉ mô
  tả quan hệ marketing/khai thác của một chặng bay.
- Kho dữ liệu lớn có thể tạo trang mỏng hoặc trùng lặp.

Các rủi ro được kiểm soát bằng review hợp đồng, khẳng định an toàn, cổng độ tin cậy và độ mới, quy
tắc tối đa ba điểm dừng có giới hạn, kho ban đầu được review và tách biệt khám phá tuyến khỏi kết quả trực
tiếp trong tương lai.

## 12. AirLabs POC và City Hub capability gate

Kế hoạch đầy đủ nằm tại `docs/product/city-hub-provider-and-commercial-expansion-plan.md`.

AirLabs là ứng viên P2 cho route, recurring schedule, airport, city, country, airline và timezone.
Trước tích hợp production phải chạy POC 14–30 ngày, xác minh API version/package, coverage,
operating-day accuracy, codeshare semantics, freshness, full-refresh cost và quyền production/SEO/
cache/snapshot/derived data.

P2 có thể bật trên City Hub:

- Direct destinations, map, airport/country-region/airline/duration/route-type filters.
- Operating days, frequency đã dedupe, freshness và provenance.
- City-level aggregation và route groups do Tripways tính.

P2 không được bật chỉ từ AirLabs:

- Estimated fare, price filter, cheapest month hoặc price trend.
- Live availability, booking hoặc affiliate CTA dựa trên offer.
- Year-round/seasonal claim khi thiếu effective date range hoặc lịch sử đủ tin cậy.

City Hub P2 phải render đúng khi toàn bộ price và commercial module vắng mặt.

## 13. Page capability sau khi có dữ liệu licensed

- City Hub tập trung khám phá direct destinations theo city; Route Page hỗ trợ direct và hành trình
  có tối đa ba điểm dừng. Airport Page tập trung arrive/depart logistics, với verified direct routes
  hai chiều là utility phụ.
- City discovery có thể dùng departure-airport, destination geography, duration và price facet khi
  capability tương ứng được phê duyệt. Không áp các facet đó mặc định cho Airport Page.
- Estimated fare trên City/Route discovery phải ghi rõ range, currency, method, confidence, sample
  window, expiry và trạng thái unavailable. Airport Page không đưa estimated airfare vào verified
  flights block; estimated transport cost vẫn được phép khi có source và freshness.
- Read model không duy trì standalone airline section chỉ vì provider có airline data; airline chỉ
  xuất hiện khi giúp so sánh route hoặc làm filter.
