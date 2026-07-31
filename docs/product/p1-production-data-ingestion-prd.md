# PRD P1: Nhập dữ liệu production

**Trạng thái:** Đề xuất để duyệt sản phẩm  
**Ngày:** 2026-07-30  
**Chủ sở hữu:** Tripways  
**Kho mã chính:** `tripways-backend`

## 1. Vấn đề

P0 đã chứng minh một pipeline nhỏ ở local bằng provider giả lập và smoke test với API thật đã được
phê duyệt. Tuy nhiên, pipeline đó chỉ xác nhận ranh giới kỹ thuật; nó chưa đủ để công bố kho sân bay,
thành phố hoặc quốc gia production ở quy mô thật.

Tripways vẫn thiếu workflow nhập dữ liệu production có thể kiểm toán, bao gồm quyền nguồn, batch bất
biến, validation đầy đủ, diff quy mô thật, phê duyệt thay đổi, xuất bản nguyên tử, retention, vận
hành định kỳ và rollback.

Đưa file nguồn trực tiếp vào bảng public sẽ khiến lỗi khó chẩn đoán và có thể công bố dữ liệu cũ,
sai định dạng hoặc không đủ bản quyền.

## 2. Mục tiêu

Cho phép người vận hành nhập một nguồn dữ liệu nền đã được phê duyệt vào vùng staging riêng tư, kiểm
tra chất lượng và bản tóm tắt thay đổi, sau đó xuất bản nguyên tử các bản ghi quốc gia, thành phố và
sân bay hợp lệ mà không tự động cho phép lập chỉ mục.

P1 phải mở rộng contract và bài học từ P0 thay vì tạo một pipeline song song hoặc phụ thuộc vào
provider giả lập.

## 3. Người dùng mục tiêu

- Người vận hành dữ liệu nhập snapshot nguồn đã được review.
- Chủ sản phẩm phê duyệt quyền nguồn và phạm vi xuất bản.
- Kỹ sư chẩn đoán lỗi validation và xuất bản.

## 4. Nguồn ban đầu

Nguồn dữ liệu nền production đầu tiên là OurAirports, với điều kiện quyền nguồn và giấy phép được
ghi nhận, review trước khi sử dụng.

P1 bao phủ quốc gia, thành phố, vùng, định danh sân bay, mã, tọa độ, trường múi giờ từ nguồn khi có và
lineage nguồn. P1 không suy luận tuyến bay chỉ từ việc sân bay tồn tại.

## 5. Hành trình người dùng

### Hành trình A: Đăng ký nguồn

1. Người vận hành ghi nhận định danh nguồn, ghi chú giấy phép, phạm vi môi trường và quyền rõ ràng
   cho production, SEO, cache và dữ liệu phái sinh.
2. Hệ thống từ chối xuất bản production nếu thiếu quyền bắt buộc.

### Hành trình B: Nhập và kiểm tra snapshot

1. Người vận hành cung cấp snapshot bằng lệnh thủ công rõ ràng hoặc trigger định kỳ được phê duyệt.
2. Hệ thống tạo batch bất biến với checksum, thời gian nguồn và số lượng dòng.
3. Hệ thống parse và validation bản ghi vào các bảng staging riêng tư.
4. Người vận hành nhận số lượng chấp nhận, từ chối, cảnh báo và chưa phân giải cùng mẫu lỗi có giới
   hạn.

### Hành trình C: Review diff

1. Hệ thống so sánh snapshot staging hợp lệ với bộ dữ liệu đang xuất bản.
2. Người vận hành review tổng số thêm mới, thay đổi, ngừng hoạt động và không đổi.
3. Thay đổi có tính phá hủy hoặc bất thường cần được phê duyệt rõ ràng.

### Hành trình D: Xuất bản nguyên tử

1. Người vận hành xuất bản batch đã duyệt bằng khóa idempotency.
2. Quốc gia, thành phố và sân bay được cập nhật trong một transaction.
3. Nếu bất kỳ invariant nào thất bại, transaction rollback và bộ dữ liệu đã xuất bản trước đó vẫn
   hoạt động.
4. Lần xuất bản ghi nhận phiên bản dữ liệu và kết quả.

## 6. Yêu cầu chức năng

### 6.1 Quyền nguồn

- Mỗi nguồn lưu riêng quyền production, SEO, cache và dữ liệu phái sinh.
- Quyền được kiểm tra trước khi xuất bản và trước khi xác định đủ điều kiện pSEO.
- Cấm sử dụng OpenFlights.
- Ghi chú giấy phép và trường dữ liệu provider thô không được trả qua API public.

### 6.2 Quản lý batch thô

- Mỗi batch trở thành bất biến sau khi tạo.
- Định danh batch gồm nguồn, checksum, thời gian nhận, thời gian nguồn khi có và môi trường.
- Nhập lại cùng một snapshot phải có tính idempotent.
- Dữ liệu nguồn thô nằm trong schema không được expose.

### 6.3 Validation

- Kiểm tra mã bắt buộc, tọa độ, loại được hỗ trợ, tham chiếu quốc gia và quy tắc định danh canonical.
- Báo cáo rõ định danh trùng và xung đột.
- Giá trị tùy chọn chưa biết phải giữ là chưa biết, không chuyển thành false, zero hoặc mặc định bịa
  đặt.
- Bản ghi không hợp lệ không được vào bảng đã xuất bản.

### 6.4 Diff và xuất bản

- Kết quả xuất bản báo số thêm mới, cập nhật, ngừng hoạt động, không đổi, từ chối và chưa phân giải.
- Không xóa ngầm bản ghi bị thiếu; quy tắc ngừng hoạt động theo nguồn phải được khai báo rõ.
- Xuất bản có tính transaction và idempotent.
- Batch thất bại không được thay thế bộ dữ liệu đang xuất bản.
- Xuất bản tạo phiên bản dữ liệu ổn định cho các read model phía sau.

### 6.5 Review và khả năng lập chỉ mục

- Entity nền mới xuất bản mặc định không được lập chỉ mục.
- Xuất bản dữ liệu nền không tạo khẳng định về dịch vụ bay định kỳ.
- Cần review sản phẩm và điều kiện dữ liệu tuyến bay trước khi cho phép pSEO lập chỉ mục.
- Dữ liệu mẫu phát triển luôn tách biệt dữ liệu production.

### 6.6 Vận hành

- Người vận hành xem được tóm tắt batch, validation, diff và xuất bản mà không đọc lỗi cơ sở dữ liệu
  thô.
- Log có cấu trúc gồm request ID, nguồn, batch ID, hành động, trạng thái, thời lượng và mã lỗi ổn định.
- Log không chứa khóa bí mật hoặc toàn bộ payload thô.

## 7. Yêu cầu phi chức năng

- Tất cả bảng expose phải dùng RLS và phân quyền tối thiểu.
- Ingestion yêu cầu danh tính worker đặc quyền và rate limit.
- Lệnh nhập và xuất bản phải an toàn khi retry.
- Có thể tái dựng bộ dữ liệu đầy đủ theo cách xác định từ migration và snapshot nguồn được phê duyệt.
- Validation và xuất bản phải xử lý bộ dữ liệu ban đầu trong giới hạn thời gian vận hành được xác
  lập qua staging test.
- Snapshot nguồn và backup cơ sở dữ liệu tuân theo chính sách lưu giữ rõ ràng.

## 8. Chỉ số thành công

- 100% bản ghi quốc gia, thành phố và sân bay đã xuất bản có lineage nguồn.
- 100% lần xuất bản production có batch bất biến, kết quả validation, diff, bản ghi xuất bản và phiên
  bản dữ liệu.
- Xuất bản trùng batch không tạo bản ghi domain trùng.
- Snapshot cố ý không hợp lệ không làm thay đổi bộ dữ liệu đã xuất bản trước đó.
- Không entity mới nhập nào tự động trở thành indexable.
- Review vận hành giải thích được từng nhóm bản ghi bị từ chối và thay đổi ngừng hoạt động quan trọng.

## 9. Cổng nghiệm thu

P1 chỉ được nghiệm thu khi:

- Quyền nguồn đã được review và ghi nhận.
- Một snapshot thật hoàn thành import, validation, diff và xuất bản trên staging.
- Đã kiểm chứng nguồn không hợp lệ, batch trùng, lỗi một phần và rollback.
- Entity đã xuất bản vẫn không được lập chỉ mục.
- Security Advisor và Performance Advisor không còn vấn đề chặn ra mắt.
- Quy trình backup và phục hồi đã được tài liệu hóa và kiểm thử ở mức đã thống nhất.

## 10. Ngoài phạm vi

- Nhập tuyến bay và lịch bay định kỳ.
- Kết quả và giá trực tiếp.
- Tự động xuất bản pSEO toàn cầu.
- Nền tảng tích hợp dữ liệu đa mục đích.
- Giao diện quản trị trên trình duyệt.
- Streaming ingestion, hàng đợi và change data capture theo thời gian thực.

## 11. Rủi ro

- Định danh nguồn có thể đổi hoặc xung đột giữa các snapshot.
- Diff xóa lớn có thể là lỗi nguồn thay vì sân bay thật sự đóng cửa.
- Giấy phép có thể cho phép hiển thị nhưng cấm cache hoặc dữ liệu pSEO phái sinh.
- Snapshot thô có thể chứa cột bất ngờ hoặc encoding lỗi.

Các rủi ro được kiểm soát bằng batch bất biến, parser nghiêm ngặt, quyền rõ ràng, cổng bất thường,
xuất bản theo transaction và bảo toàn bộ dữ liệu tốt gần nhất.
