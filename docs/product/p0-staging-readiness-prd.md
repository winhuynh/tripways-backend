# PRD P0: Sẵn sàng cho staging

**Trạng thái:** Đề xuất để duyệt sản phẩm  
**Ngày:** 2026-07-30  
**Chủ sở hữu:** Tripways  
**Kho mã:** `tripways-backend`, `tripways-web`

## 1. Vấn đề

Tripways đã có nguyên mẫu cục bộ đáng tin cậy nhưng các hành trình chính chưa hoạt động end-to-end
một cách ổn định. Trang thành phố phụ thuộc Edge Runtime cục bộ, trang sân bay dùng một ranh giới dữ
liệu khác, một số liên kết ở trang chủ dẫn tới trang chưa tồn tại và quy trình build production chưa
hoàn toàn có thể tái lập.

Nếu chưa có staging ổn định, nhóm sản phẩm không thể kiểm chứng quyết định trên thiết bị thật, hạ
tầng từ xa hoặc với người thử nghiệm đại diện.

## 2. Mục tiêu

P0 được chia thành hai phase tuần tự:

- **P0A — Local Release Candidate:** Hoàn thành và kiểm chứng ở local toàn bộ hành vi không phụ
  thuộc cloud, bao gồm một pipeline nhập dữ liệu nhỏ từ provider giả lập và một smoke test với API
  thật đã được phê duyệt.
- **P0B — Remote Staging:** Đưa đúng release candidate của P0A lên staging riêng tư để xác nhận
  deployment, secrets, network, cache, monitoring, smoke test và rollback.

P0A phải đạt tối thiểu 90% danh mục hành vi P0 trước khi bắt đầu P0B. P0B không được trở thành nơi
hoàn thiện logic sản phẩm còn thiếu ở local.

## 3. Người dùng mục tiêu

- Chủ sản phẩm duyệt phạm vi và chất lượng nội dung.
- Kỹ sư kiểm tra tích hợp và triển khai từ xa.
- Một nhóm nhỏ người thử nghiệm được mời để đánh giá điều hướng và giá trị của khám phá tuyến bay.

Công cụ tìm kiếm và người dùng đại chúng không phải đối tượng của P0.

## 4. Hành trình người dùng

### Hành trình A: Từ trang chủ tới khám phá thành phố

1. Người duyệt mở trang chủ staging.
2. Người duyệt chọn một thành phố đang có dữ liệu.
3. Trang thành phố tải thông tin định danh, sân bay, điểm đến bay thẳng, hãng bay, phân tích, câu hỏi
   thường gặp và bản đồ tuyến bay.
4. Người duyệt áp dụng bộ lọc được hỗ trợ và nhận kết quả ổn định hoặc trạng thái trống hữu ích.

### Hành trình B: Từ trang chủ hoặc thành phố tới khám phá sân bay

1. Người duyệt chọn một sân bay đang có dữ liệu.
2. Trang sân bay tải thống kê tuyến, tuyến đi/đến, hướng dẫn di chuyển, phòng chờ, lưu ý, câu hỏi
   thường gặp và liên kết liên quan.
3. Người duyệt đổi chiều tuyến bay và áp dụng bộ lọc được hỗ trợ.

### Hành trình C: Phục hồi khi có lỗi

1. Ranh giới dữ liệu không khả dụng hoặc trả về phản hồi sai hợp đồng.
2. Người duyệt thấy trạng thái lỗi có giới hạn thay vì bộ tải vô hạn, stack trace thô hoặc trang
   trắng.
3. Trang vẫn không được lập chỉ mục.

### Hành trình D: Nhập dữ liệu thử nghiệm ở local

1. Kỹ sư chạy provider API giả lập bằng payload chuẩn có tính xác định.
2. Hệ thống nhận một batch nhỏ gồm quốc gia, thành phố và sân bay, kiểm tra dữ liệu, ghi nhận lỗi và
   xuất bản vào Supabase local.
3. Chạy lại cùng batch không tạo dữ liệu trùng.
4. Một batch cố ý sai thất bại an toàn và không thay đổi dữ liệu tốt đã xuất bản.
5. Kỹ sư chạy smoke test tùy chọn mạng với một API thật đã được phê duyệt và một tập dữ liệu giới
   hạn.
6. Dữ liệu API thật trong P0 chỉ phục vụ local/staging, luôn `noindex` và không được coi là pipeline
   production hoàn chỉnh.

## 5. Yêu cầu chức năng

### 5.1 P0A — Local Release Candidate

- Trang chủ, thành phố và sân bay phải chạy end-to-end với Supabase và Edge Functions local.
- Cùng một server boundary được dùng cho thành phố và sân bay.
- Build production, test, lint và typecheck phải chạy được từ lệnh đã tài liệu hóa.
- Không hành vi sản phẩm bắt buộc nào chỉ có thể kiểm thử sau khi deploy staging.
- P0A phải tạo release candidate bất biến theo commit hoặc định danh source state; P0B triển khai
  đúng source state này.

### 5.2 Pipeline dữ liệu nhỏ ở local

- Có một provider API giả lập cục bộ triển khai contract trung lập provider và trả payload có tính
  xác định.
- Payload mẫu tối thiểu gồm một quốc gia, một thành phố và một sân bay hợp lệ, cùng các trường hợp
  trùng, thiếu trường bắt buộc và dữ liệu sai định dạng.
- Luồng local phải thể hiện các ranh giới: nhận batch, kiểm tra schema, chuẩn hóa, từ chối bản ghi
  lỗi, xuất bản bản ghi hợp lệ và báo cáo kết quả.
- Batch phải có checksum hoặc định danh idempotency; chạy lại không tạo bản ghi trùng.
- Dữ liệu thô không được ghi trực tiếp vào bảng public.
- Một lần nhập thất bại không được làm thay đổi bộ dữ liệu tốt gần nhất.
- API thật chỉ được gọi bằng smoke test rõ ràng, không nằm trong bộ test mặc định và không làm test
  phụ thuộc mạng.
- API thật phải được chủ sở hữu phê duyệt về nguồn và quyền trước khi gọi. Credentials, nếu có,
  chỉ nằm trong biến môi trường local.
- Smoke test API thật phải giới hạn số bản ghi, lưu lại sanitized fixture để test offline và không
  tự động bật `production_allowed` hoặc `seo_allowed`.
- P0 không cần hoàn thiện diff quy mô lớn, approval workflow, retention, scheduler hoặc pipeline
  publication production; các phần này thuộc P1.

### 5.3 Kho nội dung local và staging

- Local và staging chỉ hiển thị thành phố và sân bay có dữ liệu phát triển hoàn chỉnh.
- Trang chủ, header, footer, thư mục và liên kết hành lang bay không được dẫn tới trang chưa tồn tại.
- Trang dùng fixture, provider giả lập hoặc API thật trong P0 phải luôn được đánh dấu phi production
  và `noindex`.
- Local và staging không được đưa dữ liệu P0 vào sitemap production.

### 5.4 Ranh giới máy chủ ổn định

- Đọc dữ liệu thành phố và sân bay phải tuân theo một mô hình tin cậy phía máy chủ đã được tài liệu
  hóa.
- Khóa `service-role` hoặc khóa bí mật không được xuất hiện trong bundle trình duyệt, props, log hoặc
  phản hồi lỗi.
- Phản hồi RPC bên ngoài phải được kiểm tra hợp đồng trước khi render.
- Endpoint đọc công khai phải giới hạn đầu vào và dùng mã lỗi ổn định.

### 5.5 Hành vi trang

- Trang chủ, thành phố và sân bay phải render trên desktop và mobile.
- Trạng thái tải phải kết thúc bằng nội dung, không tìm thấy hoặc lỗi có giới hạn.
- Metadata canonical phải trỏ về URL gốc của trang.
- URL có bộ lọc phải giữ `noindex` và canonical về trang gốc.
- Newsletter và thao tác điều hướng chưa hoạt động phải được xóa, vô hiệu hóa hoặc ghi rõ là hành vi
  preview.

### 5.6 Bộ nhớ đệm

- Dữ liệu trang ổn định có thể dùng cache HTTP của nền tảng hoặc cơ chế revalidation của Next.js.
- Định danh cache phải gồm định danh trang, locale, bộ lọc liên quan và phiên bản dữ liệu.
- Dữ liệu mẫu không được cache hoặc phục vụ như nội dung production có thể lập chỉ mục.
- P0 không thêm Redis hoặc dịch vụ cache chuyên dụng khác.

### 5.7 P0B — Triển khai staging

- Ứng dụng Next.js full-stack phải chạy trên nền tảng hỗ trợ Server Components, Route Handlers, SSR
  và biến môi trường phía máy chủ.
- Nếu dùng Cloudflare, phải triển khai bằng Workers/OpenNext thay vì xuất static lên Pages.
- Staging sử dụng Supabase project và bí mật môi trường riêng.
- Staging phải được bảo vệ bằng kiểm soát truy cập hoặc URL preview khó đoán và luôn công bố
  `noindex`.
- P0B phải triển khai đúng release candidate đã vượt qua P0A; thay đổi logic phát hiện trên staging
  phải quay lại local, được kiểm thử và tạo release candidate mới.
- Migration và seed staging phải tái tạo được từ kho mã; không sửa schema thủ công trên dashboard.

## 6. Yêu cầu phi chức năng

- Không còn vấn đề bảo mật mức nghiêm trọng hoặc cao chưa xử lý.
- Phản hồi trang chính không làm lộ lỗi cơ sở dữ liệu hoặc nhà cung cấp thô.
- Thao tác đọc công khai có bảo vệ lạm dụng cơ bản.
- Một section tùy chọn không khả dụng không được làm hỏng dữ liệu đã lưu.
- Build production có thể tái lập mà không cần bước thiết lập tương tác không được khai báo.
- Các trang chính đáp ứng yêu cầu cơ bản về bàn phím, focus, nhãn truy cập và responsive.

### 6.1 Cách đo mức hoàn thành 90% ở local

Mức hoàn thành P0A được tính trên 12 năng lực có trọng số bằng nhau:

1. Dựng lại Supabase local từ migration và seed.
2. Nhập batch hợp lệ từ provider API giả lập.
3. Từ chối batch hoặc bản ghi sai mà không làm hỏng dữ liệu tốt.
4. Chạy lại batch có tính idempotent.
5. Smoke test một API thật đã được phê duyệt với tập dữ liệu giới hạn.
6. Trang chủ chỉ điều hướng tới nội dung đang tồn tại.
7. Trang thành phố tải end-to-end.
8. Trang sân bay tải end-to-end.
9. Bộ lọc và phân trang tuyến trả kết quả hoặc empty state đúng.
10. Bản đồ tuyến tải hoặc fallback có chủ đích.
11. Trạng thái loading, 404 và lỗi kết thúc đúng trên desktop và mobile.
12. Format, lint, typecheck, kiểm thử bắt buộc, security guard và production build đều pass.

Một năng lực chỉ được tính là đạt khi có bằng chứng từ lệnh kiểm thử tự động hoặc smoke test đã tài
liệu hóa. P0A cần đạt ít nhất 11 trên 12 năng lực, tương đương 91,7%. Năng lực chưa đạt phải có nguyên
nhân phụ thuộc cloud đã được chứng minh; lỗi logic, dữ liệu, build hoặc kiểm thử local không được
chuyển sang P0B.

## 7. Chỉ số thành công

- 100% kiểm thử bắt buộc chạy offline; test mặc định không phụ thuộc API bên ngoài.
- Provider giả lập chứng minh được happy path, batch trùng, bản ghi sai và rollback ở local.
- Một smoke test API thật đã phê duyệt nhập thành công một tập dữ liệu nhỏ vào Supabase local.
- P0A đạt ít nhất 90% danh mục hành vi P0 trước khi cho phép bắt đầu P0B.
- 100% liên kết staging đã khai báo trả về trải nghiệm 2xx, 404 hoặc lỗi có chủ đích.
- Trang chủ, một trang thành phố và một trang sân bay vượt qua smoke test desktop và mobile.
- Tất cả trang dùng dữ liệu mẫu đều phát `noindex`.
- Không bundle phía client nào chứa khóa `service-role` hoặc bí mật.
- CI vượt qua format, lint, typecheck, unit test, SQL contract test và production build.
- Ba lần chạy smoke test staging liên tiếp hoàn tất mà không lỗi tích hợp.

## 8. Cổng nghiệm thu

### 8.1 Cổng P0A

P0A chỉ được nghiệm thu khi:

- Homepage, city page, airport page, route filters, route map và error/not-found states chạy được ở
  local.
- Provider API giả lập và pipeline nhập dữ liệu nhỏ vượt qua kiểm thử offline.
- Một API thật đã được phê duyệt vượt qua smoke test giới hạn ở local.
- Chạy lại cùng batch không tạo dữ liệu trùng; batch lỗi không thay đổi dữ liệu tốt.
- Tất cả dữ liệu P0 giữ trạng thái phi production và `noindex`.
- Format, lint, typecheck, unit test, contract test, SQL E2E và production build đều pass.
- Ma trận hành vi P0A đạt tối thiểu 90%; 10% còn lại chỉ được là hành vi phụ thuộc cloud được liệt kê
  rõ.

### 8.2 Cổng P0B

P0B chỉ được nghiệm thu khi:

- URL staging hoạt động mà không cần hạ tầng cục bộ.
- Source state đã triển khai đúng với release candidate P0A được nghiệm thu.
- Hành trình thành phố và sân bay sử dụng ranh giới máy chủ nhất quán, đã review.
- Các lỗi runtime ghi nhận trong lần review hiện tại đã được xử lý.
- Liên kết trang chủ bị hỏng hoặc mang tính suy đoán đã bị xóa hoặc giới hạn vào kho dữ liệu hiện có.
- Hành vi lỗi và không tìm thấy đã được kiểm chứng.
- Staging luôn không được lập chỉ mục.
- Quy trình triển khai và rollback đã được tài liệu hóa.

P0 chỉ hoàn tất khi cả P0A và P0B đều được nghiệm thu.

## 9. Ngoài phạm vi

- Ra mắt tên miền production.
- Dữ liệu production thật.
- Pipeline production đầy đủ, ingestion theo lịch và xuất bản quy mô lớn.
- Lập chỉ mục trên công cụ tìm kiếm.
- Lịch bay có bản quyền và giá trực tiếp.
- Kiếm tiền qua liên kết.
- Phân tích sản phẩm ngoài log vận hành.
- Redis, hàng đợi bền vững và kiến trúc cơ sở dữ liệu đa vùng.

## 10. Rủi ro

- Triển khai staging có thể vô tình để công cụ tìm kiếm lập chỉ mục dữ liệu mẫu.
- Ranh giới thành phố và sân bay không nhất quán có thể làm lộ đặc quyền hoặc tạo hành vi cache khác
  nhau.
- Cold start của Edge hoặc SSR từ xa có thể tạo trải nghiệm tải kém.
- Môi trường preview về sau có thể vô tình dùng lại bí mật production.
- Test phụ thuộc mạng có thể không ổn định hoặc API thật thay đổi contract.
- Pipeline nhỏ trong P0 có thể bị hiểu nhầm là đã sẵn sàng production.

Các rủi ro này được kiểm soát bằng tách biệt môi trường, metadata robots rõ ràng, kiểm tra bí mật chỉ
dùng phía máy chủ, test offline có tính xác định, smoke test API thật tách riêng, giới hạn phạm vi dữ
liệu và ranh giới P0/P1 được tài liệu hóa.
