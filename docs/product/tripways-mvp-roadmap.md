# Lộ trình sản phẩm MVP Tripways

**Trạng thái:** Đề xuất để duyệt sản phẩm  
**Ngày:** 2026-07-30  
**Phạm vi:** `tripways-backend` và `tripways-web`

## 1. Định hướng sản phẩm

Tripways là sản phẩm dữ liệu đồ thị du lịch và khám phá chuyến bay, lấy hàng không làm trọng tâm
đầu tiên. Sản phẩm giúp người dùng hiểu những tuyến bay thẳng và một điểm dừng nào thường tồn tại
giữa các thành phố và sân bay, sau đó từng bước mở rộng sang tìm kiếm chuyến bay theo ngày và
chuyển tiếp an toàn tới đối tác liên kết.

Tripways không phát hành vé, xử lý thanh toán đặt chỗ, quản lý hủy vé hoặc khẳng định tình trạng
còn chỗ theo thời gian thực dựa trên dữ liệu lịch bay đã lưu.

## 2. Nền tảng hiện tại

Nguyên mẫu cục bộ hiện có:

- Các bảng quốc gia, thành phố, sân bay, hãng bay, tuyến bay và dịch vụ bay định kỳ đã được chuẩn
  hóa.
- Khám phá tuyến bay thẳng và một điểm dừng bằng dữ liệu mẫu phát triển có tính xác định.
- Các mô hình đọc pSEO cho thành phố và sân bay.
- Nguyên mẫu trang thành phố và sân bay bằng Next.js.
- RLS, phân quyền tối thiểu, sử dụng khóa `service-role` phía máy chủ và kiểm thử hợp đồng.

Nguyên mẫu hiện chưa có:

- Môi trường staging từ xa ổn định.
- Pipeline nhập dữ liệu production hoặc nguồn dữ liệu production đã được phê duyệt.
- Nhà cung cấp dữ liệu tuyến bay hoặc lịch bay có bản quyền.
- Kết quả chuyến bay và giá theo ngày.
- Chuyển hướng liên kết và phân tích hành vi sản phẩm.
- Xuất bản sitemap production hoặc quy trình ra mắt production.

## 3. Các giai đoạn bàn giao

| Giai đoạn | Kết quả sản phẩm                                                                     | Điều kiện bắt đầu                                               | Điều kiện hoàn tất                                                                       |
| --------- | ------------------------------------------------------------------------------------ | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| P0A       | Local release candidate hoàn thành phần lớn hành vi sản phẩm và pipeline dữ liệu nhỏ | Nguyên mẫu cục bộ hiện tại                                      | Toàn bộ hành vi không phụ thuộc cloud chạy end-to-end ở local và đạt cổng chất lượng P0A |
| P0B       | Sản phẩm staging ổn định, riêng tư và `noindex`                                      | P0A được nghiệm thu                                             | Cùng release candidate hoạt động từ xa; chỉ còn khác biệt hạ tầng, bí mật và vận hành    |
| P1        | Có thể nhập và kiểm duyệt dữ liệu nền thật một cách an toàn                          | P0 được nghiệm thu                                              | Dữ liệu quốc gia, thành phố và sân bay thật được xuất bản qua pipeline có thể kiểm toán  |
| P2        | Dữ liệu tuyến bay và lịch bay có bản quyền vận hành lớp khám phá đáng tin cậy        | P1 được nghiệm thu và quyền sử dụng nhà cung cấp được phê duyệt | Khám phá tuyến bay và pSEO sử dụng dữ liệu production mới, có bản quyền                  |
| P3        | Người dùng có thể tìm chuyến bay theo ngày và rời Tripways qua liên kết an toàn      | P2 được nghiệm thu và đã chọn đối tác tìm kiếm trực tiếp        | MVP production đáp ứng các cổng ra mắt, bảo mật, phân tích và độ tin cậy                 |

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
- Hành trình nhiều thành phố hoặc có hơn một điểm nối chuyến.
- Tài khoản thành viên, gói đăng ký và tính năng cao cấp.
- Redis, hàng đợi bền vững hoặc công cụ tìm kiếm riêng khi chưa có nhu cầu đã đo được.

## 7. Quản trị

- Nghiệm thu sản phẩm dựa trên điều kiện hoàn tất trong PRD của từng giai đoạn.
- Triển khai kỹ thuật tuân theo kế hoạch triển khai tương ứng.
- Mọi thao tác triển khai production, thay đổi tên miền, ký hợp đồng dữ liệu, thao tác cơ sở dữ liệu
  từ xa hoặc cấp bí mật đều cần chủ sở hữu phê duyệt rõ ràng.
- Thay đổi phạm vi đáng kể phải cập nhật PRD tương ứng trước khi triển khai.
