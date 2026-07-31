# PRD P2: Dữ liệu chuyến bay có bản quyền

**Trạng thái:** Đề xuất để duyệt sản phẩm  
**Ngày:** 2026-07-30  
**Chủ sở hữu:** Tripways  
**Kho mã:** `tripways-backend`, `tripways-web`

## 1. Vấn đề

Dữ liệu định danh sân bay và thành phố không đủ để trả lời người dùng thường có thể bay đi đâu.
Tripways cần dữ liệu tuyến bay và lịch bay định kỳ có bản quyền, đủ mới và đủ quyền để vận hành khám
phá tuyến và pSEO mà không mô tả lịch bay đã lưu như tình trạng còn chỗ trực tiếp.

Dữ liệu tuyến mẫu chứng minh được hành vi kỹ thuật nhưng không thể công bố như sự thật production.

## 2. Mục tiêu

Nhập và xuất bản tuyến bay có hướng cùng dịch vụ bay định kỳ có bản quyền, tái dựng read model tuyến
thẳng và một điểm dừng, đồng thời cung cấp trang khám phá thành phố và sân bay đáng tin cậy với độ
mới, độ tin cậy và điều kiện lập chỉ mục dựa trên nguồn rõ ràng.

## 3. Người dùng mục tiêu

- Người dùng khám phá khả năng bay thẳng và một điểm dừng.
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

### Hành trình C: Khám phá hành trình một điểm dừng

1. Người dùng tìm điểm đi và điểm đến.
2. Tripways trả các mẫu lịch bay thẳng và một điểm dừng đủ điều kiện.
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
- Payload thô và trường riêng của provider nằm trong vùng private.
- Batch tái sử dụng mô hình validation, diff, idempotency và xuất bản nguyên tử của P1.
- Dữ liệu sai hoặc thiếu bản quyền không được thay thế đồ thị tuyến đã xuất bản.

### 6.2 Sự thật về tuyến bay

- Tuyến bay có hướng và giữ lineage nguồn.
- Dịch vụ định kỳ giữ thời gian hiệu lực, ngày khai thác, giờ địa phương, độ lệch ngày đến, hãng bay,
  độ tin cậy và thời gian xác minh khi có.
- Tần suất và mùa vụ bị thiếu phải giữ là chưa biết.
- Không gắn nhãn dữ liệu đã lưu là trực tiếp, còn chỗ, có thể đặt hoặc rẻ nhất.

### 6.3 Khám phá tuyến

- Tái dựng tuyến thẳng và một điểm dừng sau khi xuất bản thành công.
- Tương thích nối chuyến, bộ lọc, facet, phân trang và xếp hạng vẫn thuộc sở hữu cơ sở dữ liệu.
- Kết quả tìm kiếm gồm phiên bản dữ liệu, độ mới, độ tin cậy và thông báo đây là lịch bay đã lưu.
- Lỗi provider không được biến thành kết quả sai “tuyến không tồn tại”.

### 6.4 Xuất bản pSEO

- Phạm vi production ban đầu là một tập thành phố và sân bay giới hạn đã review.
- Trang chỉ được index khi đạt quyền nguồn, độ sâu tuyến, độ mới, độ tin cậy, metadata đã review,
  định danh canonical và yêu cầu internal link.
- Trang trống, cũ, lịch sử, độ tin cậy thấp, chỉ dùng fixture hoặc chưa review không được index.
- Sitemap đọc trạng thái indexability tính sẵn thay vì chạy graph query toàn cục.
- Tổ hợp bộ lọc canonical về trang gốc và không được index trừ khi được tuyển chọn riêng.

### 6.5 Cache và làm mới

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
- Khám phá tuyến thẳng và một điểm dừng hoạt động từ dữ liệu có bản quyền.
- Kho trang thành phố và sân bay production ban đầu đã được review.
- Sitemap chỉ chứa trang đủ điều kiện.
- Đã kiểm chứng độ mới, ingestion bị lỡ và rollback.
- Cache tuân thủ quyền provider.
- Trang production không đưa ra khẳng định về giá hoặc tình trạng còn chỗ trực tiếp.

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
- Tuyến một điểm dừng có thể tương thích về lý thuyết nhưng không bán được về thương mại.
- Kho dữ liệu lớn có thể tạo trang mỏng hoặc trùng lặp.

Các rủi ro được kiểm soát bằng review hợp đồng, khẳng định an toàn, cổng độ tin cậy và độ mới, quy
tắc một điểm dừng giới hạn, kho ban đầu được review và tách biệt khám phá tuyến khỏi kết quả trực
tiếp trong tương lai.
