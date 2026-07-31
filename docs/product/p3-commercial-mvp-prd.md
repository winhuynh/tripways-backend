# PRD P3: MVP thương mại

**Trạng thái:** Đề xuất để duyệt sản phẩm  
**Ngày:** 2026-07-30  
**Chủ sở hữu:** Tripways  
**Kho mã:** `tripways-backend`, `tripways-web`

## 1. Vấn đề

Khám phá tuyến giúp người dùng hiểu các kết nối có khả năng tồn tại nhưng chưa trả lời chuyến bay và
đề nghị nào đang được provider trả về cho ngày cụ thể. Tripways cũng thiếu đường chuyển tiếp an toàn
tới đối tác liên kết và hệ thống phân tích cần thiết để hiểu giá trị sản phẩm, độ tin cậy provider
và chuyển đổi thương mại.

## 2. Mục tiêu

Ra mắt MVP khám phá chuyến bay production, nơi người dùng có thể đi từ trang tuyến hoặc pSEO đáng tin
cậy tới tìm kiếm theo ngày, so sánh kết quả provider đã chuẩn hóa và đi qua chuyển hướng liên kết an
toàn, trong khi Tripways đo được kết quả sản phẩm và vận hành.

## 3. Người dùng mục tiêu

- Người dùng nghiên cứu tuyến từ trang thành phố hoặc sân bay.
- Người dùng đã có ngày đi, số hành khách và hạng ghế mong muốn.
- Chủ sản phẩm đo mức hữu ích của tìm kiếm và lượt rời qua liên kết.
- Người vận hành theo dõi độ trễ, lỗi và chi phí provider.

## 4. Giá trị cung cấp

Tripways kết hợp:

- Bản đồ kết nối chuyến bay định kỳ có thể duyệt và truy vết nguồn.
- Trang khám phá thành phố, sân bay, hãng bay, quốc gia và tuyến hữu ích.
- Kết quả provider theo ngày khi người dùng sẵn sàng đánh giá chuyến đi.
- Chuyển tiếp minh bạch tới hãng bay hoặc OTA để hoàn tất đặt chỗ.

Tripways vẫn là sản phẩm metasearch và khám phá, không phải đại lý du lịch.

## 5. Hành trình người dùng

### Hành trình A: Bắt đầu tìm kiếm theo ngày

1. Người dùng bắt đầu từ trang tuyến, thành phố, sân bay hoặc ô tìm kiếm trang chủ.
2. Người dùng nhập điểm đi, điểm đến, ngày, số hành khách và hạng ghế.
3. Tripways validation yêu cầu và bắt đầu tìm kiếm trung lập provider.
4. Người dùng thấy tiến trình, kết quả hoàn tất, không có kết quả hoặc trạng thái lỗi có giới hạn.

### Hành trình B: So sánh kết quả

1. Tripways hiển thị các kết quả đã chuẩn hóa được trả về cho ngày yêu cầu.
2. Người dùng lọc theo giá, hãng bay, số điểm dừng, thời gian, thời lượng, sân bay, hạng ghế và thuộc
   tính hành lý hoặc giá vé được hỗ trợ.
3. Mỗi kết quả xác định tiền tệ, độ mới/thời gian hết hạn và giới hạn liên quan.

### Hành trình C: Rời Tripways qua đối tác liên kết

1. Người dùng chọn một kết quả.
2. Tripways tạo hoặc phân giải outbound token thời hạn ngắn.
3. Token chỉ chuyển hướng tới domain hãng bay hoặc OTA trong danh sách cho phép gắn với kết quả
   provider.
4. Tripways ghi nhận sự kiện click liên kết có giới hạn mà không lưu dữ liệu thanh toán hoặc dữ liệu
   hành khách không cần thiết.

### Hành trình D: Phục hồi khi provider lỗi

1. Tìm kiếm trực tiếp timeout, trả lỗi hoặc không có kết quả.
2. Tripways hiển thị trạng thái trung thực và giữ trang khám phá tuyến nền vẫn hữu ích.
3. Lỗi provider không thay đổi dữ liệu tồn tại tuyến đã lưu.

## 6. Yêu cầu chức năng

### 6.1 Yêu cầu tìm kiếm trực tiếp

- Đầu vào gồm điểm đi và đến chuẩn, ngày đi hoặc các ngày hành trình được hỗ trợ, số hành khách có
  giới hạn và hạng ghế được hỗ trợ.
- Máy chủ validation toàn bộ đầu vào và từ chối yêu cầu không hỗ trợ hoặc lạm dụng.
- Mỗi lượt tìm có Tripways search ID không tiết lộ nội bộ.
- Đầu vào client không được chọn credential provider, giá hoặc đích liên kết tùy ý.

### 6.2 Adapter provider

- Hợp đồng trung lập provider hỗ trợ hoàn tất đồng bộ hoặc polling bất đồng bộ.
- Payload riêng của provider được ánh xạ thành kết quả và lỗi Tripways ổn định.
- Timeout, retry, thời gian hết hạn và circuit behavior phải có giới hạn.
- Kết quả chỉ được cache trong thời gian và mục đích điều khoản provider cho phép.
- Không log dữ liệu hành khách thô hoặc authorization header.

### 6.3 Chuẩn hóa kết quả

- Kết quả chuẩn giữ định danh provider, các chặng, hãng khai thác và tiếp thị, số điểm dừng, lịch
  trình, thời lượng, hạng ghế, giá, tiền tệ, thời gian hết hạn và thuộc tính giá vé được hỗ trợ.
- Kết quả trùng được xử lý theo quy tắc ổn định đã tài liệu hóa.
- Hành lý hoặc thuộc tính giá vé chưa biết phải giữ là chưa biết.
- Giá luôn lấy từ phản hồi provider, không lấy từ đầu vào client.

### 6.4 Chuyển hướng liên kết

- URL đi ra được tạo từ dữ liệu provider hoặc đối tác lưu phía máy chủ.
- Đích chuyển hướng phải khớp domain đối tác trong danh sách cho phép.
- Token phải không tiết lộ nội bộ hoặc được ký, có thời hạn ngắn, chống sửa đổi và chỉ có một mục
  đích.
- Token hết hạn, bị sửa, bị thiếu hoặc trỏ tới đích không cho phép phải thất bại an toàn.
- Tripways không nhận URL chuyển hướng tùy ý từ trình duyệt.

### 6.5 Phân tích sản phẩm

- Sự kiện cho phép gồm xem trang, bắt đầu tìm, hoàn tất tìm, không có kết quả, dùng bộ lọc, lỗi
  provider, chọn kết quả và chuyển hướng liên kết.
- Sự kiện dùng schema có giới hạn và từ chối payload tùy ý.
- Analytics tránh lưu đầy đủ danh tính hành khách, payload provider thô, bí mật và dữ liệu xác thực.
- Dashboard vận hành phân biệt hành vi sản phẩm với sức khỏe provider.

### 6.6 Trải nghiệm web production

- Trang tìm kiếm và kết quả hoạt động trên mobile và desktop.
- Trạng thái tải, polling, một phần, không kết quả, timeout, kết quả hết hạn và provider không khả
  dụng phải rõ ràng.
- Trang giải thích việc đặt chỗ được hoàn tất với hãng bay hoặc OTA đã chọn.
- Nội dung pháp lý, quyền riêng tư, công bố affiliate và ghi nguồn phải có trước khi ra mắt công khai.

### 6.7 Kiểm soát ra mắt và tăng trưởng

- Ra mắt bắt đầu với thị trường, tuyến hoặc lưu lượng giới hạn.
- Chi phí provider có cảnh báo và giới hạn cứng khi được hỗ trợ.
- Endpoint public kết hợp giới hạn theo IP và người dùng khi có danh tính.
- Kill switch có thể tắt live search hoặc affiliate handoff mà không xóa trang khám phá tuyến.

## 7. Yêu cầu phi chức năng

- Bí mật, khóa `service-role` và credential provider luôn ở phía máy chủ.
- Endpoint tìm kiếm và chuyển hướng có rate limit và đã kiểm thử lạm dụng.
- Log dùng định danh request, search, thao tác provider và redirect ổn định.
- Giảm thiểu dữ liệu cá nhân và hành khách, chỉ lưu khi thật sự cần.
- Hết hạn kết quả ngăn hiển thị giá đã biết là cũ.
- Mục tiêu độ trễ và độ sẵn sàng provider được đo trước khi thu hút lưu lượng lớn.
- Production có monitoring, cảnh báo, backup, rollback và chủ sở hữu sự cố.

## 8. Chỉ số thành công

### Sản phẩm

- Tỷ lệ bắt đầu tìm kiếm từ trang khám phá đủ điều kiện.
- Tỷ lệ hoàn tất tìm kiếm và không có kết quả.
- Độ trễ hoàn tất provider trung vị và p95.
- Tỷ lệ chọn kết quả.
- Tỷ lệ chuyển hướng liên kết trên mỗi lượt tìm hoàn tất.
- Tỷ lệ quay lại sử dụng trang tuyến và thành phố.

### Độ tin cậy và niềm tin

- Tỷ lệ lượt tìm kết thúc bằng thành công chuẩn hóa, không kết quả rõ ràng hoặc lỗi đã biết có giới
  hạn.
- Không chuyển hướng tới domain ngoài danh sách cho phép.
- Không có giá do client kiểm soát hoặc bí mật provider bị lộ.
- Không có trang hoặc bản ghi fixture trong đầu ra production indexable.
- Chi phí provider nằm trong giới hạn vận hành đã phê duyệt.

Mục tiêu số liệu thương mại ban đầu được đặt sau khi staging tạo baseline đại diện. Điều này không
nới lỏng các cổng bảo mật, redirect, fixture hoặc quyền dữ liệu.

## 9. Cổng nghiệm thu

P3 chỉ được nghiệm thu khi:

- Hợp đồng live-search và affiliate provider đã được phê duyệt.
- Luồng end-to-end gồm tìm kiếm, polling khi cần, chuẩn hóa kết quả và chuyển hướng an toàn vượt qua
  staging.
- Rate limit, kiểm soát chi phí, timeout và kill switch đã được kiểm chứng.
- Schema analytics và chính sách lưu giữ dữ liệu riêng tư đã được phê duyệt.
- Nội dung pháp lý, quyền riêng tư, affiliate và ghi nguồn đã được xuất bản.
- Tên miền production, HTTPS, tách biệt môi trường, monitoring, backup và rollback đã sẵn sàng.
- Đã xác định nhóm ra mắt giới hạn và người chịu trách nhiệm.

## 10. Ngoài phạm vi

- Đặt chỗ, xuất vé, thanh toán, hoàn tiền và hủy vé.
- Quản lý yêu cầu hỗ trợ khách hàng.
- Dự đoán giá hoặc khẳng định “rẻ nhất” khi chưa đủ bằng chứng.
- Tài khoản người dùng trừ khi cần cho một hành trình sản phẩm đã được kiểm chứng.
- Tích hợp chương trình khách hàng thân thiết.
- Đặt chỗ nhiều thành phố và theo nhóm.
- Lập hành trình bằng AI.

## 11. Rủi ro

- Độ trễ và chi phí provider có thể khiến tìm kiếm ẩn danh quy mô lớn không hiệu quả.
- Kết quả có thể hết hạn giữa lúc hiển thị và lúc mở trang đối tác.
- Deeplink đối tác có thể thay đổi hoặc từ chối một số tổ hợp tìm kiếm.
- Analytics có thể thu thập nhiều dữ liệu hành khách hơn cần thiết.
- Lưu lượng SEO có thể tạo tìm kiếm tự động lạm dụng.

Các rủi ro được kiểm soát bằng phạm vi ra mắt giới hạn, giới hạn lưu lượng và chi phí, hết hạn kết
quả, monitoring provider, schema analytics nghiêm ngặt, chuyển hướng an toàn và tách biệt trang khám
phá có cache khỏi lời gọi provider trực tiếp.
