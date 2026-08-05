# Kế hoạch mở rộng dữ liệu và thương mại cho City Hub

**Trạng thái:** Kế hoạch tương lai — đã gửi AirLabs yêu cầu xác nhận quyền, chưa tích hợp  
**Cập nhật:** 2026-08-04  
**Phạm vi:** `tripways-backend`, `tripways-web`  
**Tài liệu liên quan:** `../../../docs/product/city-hub-pseo-requirements-prd.md`

## 1. Quyết định

Tripways sẽ giữ City Hub là trang khám phá mạng bay thẳng. AirLabs được xem là ứng viên cho dữ liệu
tuyến, lịch định kỳ và dữ liệu tham chiếu ở P2; AirLabs không được xem là nguồn giá, tồn chỗ, booking
hay affiliate.

Phần mở rộng được chia theo đúng roadmap:

```text
P0A/P0B: contract và fixture trung lập provider, không tích hợp production
  → P1: dữ liệu nền quốc gia, thành phố, sân bay và quyền nguồn
    → P2: AirLabs POC, route/schedule có bản quyền và City Hub production giới hạn
      → P3: indicative/live price, affiliate handoff và analytics thương mại
```

Việc chuẩn bị schema hoặc fixture sớm không làm phase sau bắt đầu và không cho phép bật UI production
khi chưa đạt cổng dữ liệu tương ứng.

### 1.1. Trạng thái quyết định provider hiện tại

- Đã gửi AirLabs yêu cầu xác nhận quyền public display, SEO index, cache, snapshot, derived data,
  attribution và kết hợp với provider khác.
- Đang chờ phản hồi bằng văn bản; chưa xem việc mua gói trả phí là bằng chứng quyền pSEO.
- Có thể mua một tháng gói 25.000 request để chạy POC local/private sau khi chủ sở hữu phê duyệt chi
  phí; POC này là research track, không làm P2 bắt đầu.
- Không publish AirLabs data, không bật indexability và không đưa credential vào production trước
  khi rights gate cùng dependency P1/P2 được đáp ứng.
- Trong khi chờ phản hồi, tiếp tục hoàn thiện P0A theo scope hiện tại.

### 1.2. Cách xử lý phản hồi AirLabs

- Nếu xác nhận đủ quyền: lưu bằng chứng vào rights register và đưa contract cụ thể vào P2 approval
  gate trước khi viết production adapter.
- Nếu trả lời có điều kiện: cập nhật retention, attribution, cache TTL, page scope và purge policy
  theo điều kiện đó rồi mới quyết định POC/publication.
- Nếu không trả lời hoặc không cho SEO/derived data: POC chỉ dùng đánh giá kỹ thuật và chuyển sang
  Cirium, OAG hoặc Aviation Edge; không public dữ liệu AirLabs.

## 2. Giá trị người dùng dự kiến

### 2.1. Nhóm lõi có thể làm bằng AirLabs ở P2

- Điểm đến bay thẳng từ một thành phố.
- Sân bay khởi hành và sân bay đến.
- Hãng khai thác và flight number khi semantics provider đã được xác minh.
- Thời lượng dự kiến.
- Ngày khai thác trong tuần.
- Tần suất tuần do Tripways tính sau khi loại trùng codeshare.
- Bộ lọc sân bay, quốc gia/khu vực, hãng bay, thời lượng và nội địa/quốc tế.
- Map route, result count và route list dùng chung một trạng thái filter.
- Freshness, provenance và cảnh báo lịch bay có thể thay đổi.

### 2.2. Nhóm Tripways phải tự chuẩn hóa hoặc tính toán

- Gom airport-to-airport thành city-to-city cho thành phố nhiều sân bay.
- Taxonomy khu vực như Đông Á, Đông Nam Á, châu Âu và châu Đại Dương.
- Dedupe codeshare và phân biệt operating carrier với marketing carrier.
- Tần suất tuần, trung bình chuyến/ngày và copy ngày khai thác.
- Domestic/international dựa trên quốc gia của sân bay đi và đến.
- Confidence và trạng thái route dựa trên lịch sử ingestion, source update và schedule verification.
- Nhóm link hữu ích: nội địa, quốc tế dưới một ngưỡng thời lượng, theo quốc gia hoặc khu vực.

### 2.3. Nhóm không được khẳng định chỉ từ AirLabs

- Giá vé một chiều hoặc khứ hồi.
- Khoảng giá ước tính, giá thấp nhất hoặc mức giá “tốt”.
- Tháng rẻ nhất và price trend.
- Tình trạng còn chỗ hoặc khả năng mua được.
- Route bay quanh năm hay theo mùa khi contract không có effective date range đáng tin cậy.
- Một vé, protected connection, self-transfer, through baggage hoặc validating carrier cho hành
  trình nhiều chặng.
- Popularity thực tế của route nếu chỉ dựa trên trường popularity của reference/search data.

## 3. Capability matrix dự kiến

| Nhu cầu City Hub       | AirLabs                        | Tripways                      | Provider khác                                | Phase bật sớm nhất              |
| ---------------------- | ------------------------------ | ----------------------------- | -------------------------------------------- | ------------------------------- |
| Direct destinations    | Routes DB                      | Gom theo city                 | Không                                        | P2                              |
| Airport/city/country   | Airports, Cities, Countries DB | Canonical mapping             | OurAirports có thể làm nền                   | P1/P2                           |
| Map geometry           | Airport coordinates + routes   | Sinh map read model           | Không                                        | P2                              |
| Airline                | Routes + Airlines DB           | Dedupe/canonicalize           | Không                                        | P2                              |
| Duration               | Routes DB                      | Normalize phút                | Không                                        | P2                              |
| Operating days         | `days`                         | UX copy và facets             | Không                                        | P2                              |
| Weekly frequency       | Record lịch                    | Dedupe codeshare và tổng hợp  | Không                                        | P2                              |
| Seasonality            | Chưa đủ theo docs công khai    | Snapshot history có kiểm soát | Dated schedule provider                      | Sau P2 POC                      |
| Departure month        | Chưa đủ                        | Filter contract               | Dated schedule/price provider                | P3 hoặc P2 extension được duyệt |
| Estimated one-way fare | Không                          | Observation aggregation       | Skyscanner Indicative hoặc nguồn được duyệt  | P3                              |
| Live fare              | Không                          | Normalize/cache theo terms    | Skyscanner Live, Duffel hoặc Amadeus         | P3                              |
| Flight affiliate link  | Không                          | Signed/allowlisted redirect   | Skyscanner Affiliate hoặc partner được duyệt | P3                              |
| Hotel/car affiliate    | Không                          | Context gating                | Affiliate vertical provider                  | P3 extension                    |

## 4. Định hướng provider

### 4.1. AirLabs

Vai trò dự kiến:

- Route và schedule truth cho lớp khám phá.
- Airports, cities, countries, airlines và timezones để enrich dữ liệu canonical.
- Không được gọi trong request render trang; dữ liệu đi qua ingestion, validation, publication và
  read model.

Trước khi ký hoặc tích hợp production phải có xác nhận bằng văn bản về:

- Quyền dùng production.
- Quyền hiển thị trên trang SEO được index.
- Quyền cache và thời lượng cache tối đa.
- Quyền lưu snapshot và dữ liệu phái sinh.
- Quyền xuất bản derived route graph và city-level aggregation.
- Quyền sử dụng logo hãng bay nếu dùng.
- Giới hạn request phút, giờ, tháng; pagination và cơ chế full refresh.
- Retention, attribution và nghĩa vụ xoá dữ liệu sau khi chấm dứt hợp đồng.

### 4.2. Skyscanner

Ứng viên ưu tiên nếu Tripways theo mô hình pSEO + metasearch affiliate:

- Indicative Prices cho khoảng giá khám phá và tháng tương đối rẻ.
- Live Prices khi user đã chọn route, ngày, passenger và cabin.
- Affiliate Links cho referral/deep link có origin, destination, date, market và currency.

Quyền truy cập phụ thuộc phê duyệt partner. Không thiết kế City Hub production phụ thuộc vào API này
trước khi được duyệt.

### 4.3. Duffel hoặc Amadeus

Chỉ cân nhắc nếu Tripways chuyển từ affiliate redirect sang live shopping hoặc bán offer:

- Gọi sau hành động của người dùng và khi đã có ngày.
- Không dùng offer hết hạn nhanh để sinh giá tĩnh cho hàng triệu trang.
- Không đưa booking, ticketing hoặc thanh toán vào MVP nếu chưa thay đổi roadmap và trách nhiệm pháp
  lý/vận hành.

## 5. Kế hoạch theo phase

### P0A — Local release candidate

**Trạng thái:** Đang thực hiện; không mở rộng scope.

- Giữ fixture deterministic cho route, schedule, price estimate eligible/missing/stale/unlicensed.
- Contract giá luôn optional; thiếu giá không biến thành `0`.
- UI local có thể minh họa giá nhưng phải `noindex` và ghi rõ fixture.
- Không thêm AirLabs credential, production adapter hoặc remote call.
- Không thêm month filter production, seasonality claim hoặc affiliate redirect.

### P0B — Remote staging

**Trạng thái:** Chưa bắt đầu.

- Chứng minh cùng contract chạy trên staging riêng tư và `noindex`.
- Kiểm tra secret isolation, HTTP cache, logs và kill switch cơ bản.
- Chỉ dùng fixture hoặc snapshot đã sanitize theo quyền.
- Không xem staging thành bằng chứng provider rights hoặc P2 acceptance.

### P1 — Production foundation ingestion

**Trạng thái:** Chưa bắt đầu.

- Xuất bản quốc gia, thành phố, sân bay, tọa độ và timezone từ nguồn nền được duyệt.
- Hoàn thiện rights matrix, immutable batch, validation, diff, atomic publication và rollback.
- Chuẩn bị canonical city-airport grouping và region taxonomy.
- Không nhập AirLabs route/schedule trong P1.
- Không bật route pSEO production, price filter hoặc affiliate.

### P2 — Licensed route and schedule data

**Trạng thái:** Chưa bắt đầu.

1. Chạy AirLabs POC 14–30 ngày trên khoảng 100 origin airports.
2. Xác minh capability matrix theo đúng API version và gói thương mại.
3. Ký/duyệt rights matrix trước khi đưa adapter vào production.
4. Ingest AirLabs vào raw/private schema; normalize sang canonical route/service.
5. Dedupe codeshare, gom city-level routes và tính frequency.
6. Publish City Hub giới hạn theo thị trường đã review.
7. Bật map, filters, operating days, duration, frequency và freshness.
8. Giữ price, month, seasonality và affiliate module tắt nếu thiếu provider đủ điều kiện.

Tiêu chí POC tối thiểu:

- Ít nhất 95% top routes có origin/destination chính xác so với nguồn đối chứng.
- Ít nhất 90% operating days khớp nguồn đối chứng.
- Dưới 3% route không hoạt động bị xuất bản là active.
- 100% codeshare trong mẫu kiểm thử được xử lý theo rule đã tài liệu hóa.
- Mọi route public có lineage, rights, freshness và confidence.
- Không request AirLabs nào chạy trong page-render path.

### P3 — Price, affiliate và commercial MVP

**Trạng thái:** Chưa bắt đầu.

- Chọn provider indicative/live price và affiliate sau khi được duyệt quyền.
- Bật month selector khi cả schedule và price coverage đạt ngưỡng.
- Bật sort theo giá và maximum estimated one-way fare chỉ khi dữ liệu đủ phủ.
- Live search chỉ chạy sau hành động user, không chạy cho bot hoặc page render.
- CTA chính của City Hub vẫn là Route Page; CTA thương mại phụ là `Kiểm tra giá` hoặc `So sánh giá`.
- Affiliate redirect do server ký/allowlist, có disclosure và analytics tối thiểu.
- Hotel, transfer, eSIM, lounge, parking và insurance chỉ bật theo context đã chọn, không chen vào
  luồng map → route results.

Ngưỡng bật estimated fare đề xuất:

- Ít nhất 70% route ưu tiên có quan sát giá trong 7 ngày gần nhất.
- Giá là one-way Economy cho một người lớn và currency rõ ràng.
- Có nhiều observation hợp lệ để tạo range; không biến một live offer thành range.
- Có `observed_at`, `freshness_status`, `source_rights` và disclaimer.
- Giá không được đưa vào title/meta description hoặc structured offer khi chưa đáp ứng điều kiện
  schema và freshness tương ứng.

## 6. Vị trí nội dung và affiliate trên City Hub

Thứ tự mở rộng được phép:

1. Hero và bốn facts.
2. Sidebar + map.
3. Result count + sort đủ điều kiện.
4. Route table với Country/Region, lịch bay và giá một chiều khi đủ quyền.
5. Fare disclaimer khi có giá.
6. Advertisement Slot A.
7. So sánh sân bay.
8. Nhóm route hữu ích được sinh từ dữ liệu.
9. Affiliate flight-search module khi P3 được bật.
10. FAQ, internal links, provenance và footer.

Quy tắc affiliate:

- Map preview có thể có CTA phụ `So sánh giá` sau khi destination đã rõ.
- Route row ưu tiên link Route Page; deep link trực tiếp chỉ khi đủ route/date context.
- Hotel, transfer và eSIM chỉ xuất hiện sau khi user chọn destination.
- Lounge và parking có thể gắn vào phần sân bay khởi hành ở P3 extension.
- Không dùng `Book from` với estimated fare; dùng `Giá một chiều ước tính` và `Kiểm tra giá`.
- Không thêm nhiều banner affiliate cạnh nhau hoặc thay thế Advertisement Slot A bằng affiliate mà
  không có quyết định sản phẩm riêng.

## 7. Kiến trúc dữ liệu dự kiến

```text
Provider ingestion job
  → raw/private batch
    → validation + rights + diff
      → canonical airports/routes/services/price observations
        → codeshare dedupe + city aggregation + facets
          → materialized City Hub page payload
            → server render + CDN/platform cache
```

Không được:

- Gọi AirLabs hoặc price provider khi render City Hub.
- Đưa provider field names vào public contract.
- Hardcode price, route facts, UX copy nghiệp vụ hoặc affiliate URL ở frontend.
- Dùng Googlebot/page view để kích hoạt live-price search.
- Xem provider timeout là bằng chứng route không tồn tại.

## 8. Analytics cần bổ sung ở P3

- Month selected.
- Sort changed.
- Estimated-fare filter applied.
- Price CTA clicked.
- Affiliate module viewed.
- Affiliate redirect succeeded/rejected/expired.
- Destination-context product clicked: hotel, transfer, eSIM, lounge hoặc parking.

Analytics không lưu full provider payload, passenger identity, payment data hoặc arbitrary URL.

## 9. Điều kiện quyết định tiếp tục hoặc dừng

### Tiếp tục AirLabs nếu

- POC đạt ngưỡng coverage và accuracy.
- Hợp đồng cho phép production, SEO, cache, snapshot và derived data.
- Chi phí full refresh phù hợp với phạm vi City Hub dự kiến.
- Dữ liệu `updated`, operating days và codeshare có semantics đủ rõ.

### Không tiếp tục hoặc chỉ dùng hạn chế nếu

- Provider không cho index dữ liệu trên pSEO pages.
- Không được lưu snapshot/derived graph đủ lâu để phục vụ page cache.
- Route coverage hoặc freshness không đạt POC.
- Codeshare duplication không thể xử lý ổn định.
- Chi phí refresh toàn bộ vượt ngân sách hoặc rate limit vận hành.

### Chỉ bật price/affiliate nếu

- Provider được duyệt và có quyền hiển thị/cache/deep-link rõ ràng.
- Coverage đạt ngưỡng sản phẩm.
- Redirect, disclosure, expiry, analytics và kill switch đã qua staging.
- City Hub vẫn hữu ích khi price provider hoặc affiliate provider bị tắt.

## 10. Hạng mục bị hoãn rõ ràng

- Tích hợp AirLabs production trước P2.
- Month filter và seasonality claim trước khi có dated evidence.
- Estimated price trước khi có licensed price provider.
- Live offers và affiliate redirect trước P3.
- Hotel, car, transfer, eSIM, insurance, lounge và parking affiliate trước khi đo được route intent.
- Booking, ticketing, payment và customer support trong roadmap MVP hiện tại.
