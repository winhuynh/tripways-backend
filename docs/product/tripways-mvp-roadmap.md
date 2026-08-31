# Lộ trình sản phẩm MVP Tripways

**Trạng thái:** P0A hoàn thành 100% (Local Release Candidate) — Chuẩn bị kích hoạt P0B (Remote Staging)  
**Cập nhật:** 2026-08-29  
**Phạm vi:** `tripways-backend` và `tripways-web`

## 1. Định hướng sản phẩm

Tripways là sản phẩm dữ liệu đồ thị du lịch và khám phá chuyến bay, lấy hàng không làm trọng tâm
đầu tiên. Sản phẩm giúp người dùng hiểu những tuyến bay từ không đến ba điểm dừng nào thường tồn tại
giữa các thành phố và sân bay, sau đó từng bước mở rộng sang tìm kiếm chuyến bay theo ngày và
chuyển tiếp an toàn tới đối tác liên kết.

Tripways không phát hành vé, xử lý thanh toán đặt chỗ, quản lý hủy vé hoặc khẳng định tình trạng
còn chỗ theo thời gian thực dựa trên dữ liệu lịch bay đã lưu.

Homepage là điểm vào khám phá: người dùng chọn `From` để mở City Hub, hoặc chọn đủ `From` và `To`
để đi tới Route Page canonical của city pair. Homepage không tự trở thành trang kết quả, không hiển
thị lời hứa về toàn bộ lịch bay và không tạo URL pSEO từ query. Tìm theo ngày, giá live và availability
là luồng thương mại riêng chỉ được bật ở P3 khi provider đã được phê duyệt; mọi URL kết quả của luồng
đó đều `noindex`.

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
- 100% test suites ở cả backend (Deno) và frontend (Vitest) đều pass sạch sẽ.

Nguyên mẫu hiện chưa có:

- Môi trường staging từ xa ổn định (P0B).
- Pipeline nhập dữ liệu production hoặc nguồn dữ liệu production đã được phê duyệt (P1).
- Nhà cung cấp dữ liệu tuyến bay hoặc lịch bay có bản quyền (P2).
- Kết quả chuyến bay và giá theo ngày (P3).
- Chuyển hướng liên kết và phân tích hành vi sản phẩm.
- Xuất bản sitemap production hoặc quy trình ra mắt production (P4).

## 3. Các giai đoạn bàn giao

| Giai đoạn | Trạng thái         | Kết quả sản phẩm                                                                            | Điều kiện hoàn tất                                                                             |
| --------- | ------------------ | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| P0A       | **Đã hoàn thành**  | Local release candidate hoàn tất 100% hành vi sản phẩm, build production và tests           | Toàn bộ hành vi không phụ thuộc cloud chạy end-to-end ở local và đạt 100% cổng chất lượng      |
| P0B       | **Kế tiếp**        | Sản phẩm staging ổn định trên Cloudflare + Supabase Cloud, riêng tư và `noindex`            | Cùng release candidate hoạt động từ xa; chỉ còn khác biệt hạ tầng, bí mật và vận hành          |
| P1        | Kế hoạch song hành | Có thể nhập và kiểm duyệt dữ liệu nền thật một cách an toàn                                 | Dữ liệu quốc gia, thành phố và sân bay thật được xuất bản qua pipeline OurAirports             |
| P2        | Kế hoạch song hành | Dữ liệu tuyến bay & đồ thị kết nối (AeroDataBox/API.market) vận hành Route Explorer và pSEO | Mạng lưới chặng bay thẳng (Direct Routes) và kết nối 1–3 stops kiểu FlightConnections sẵn sàng |
| P3        | Chưa bắt đầu       | Tích hợp giá vé quan sát và Affiliate Handoff an toàn (Travelpayouts Data API)              | MVP production đáp ứng cổng thương mại, affiliate CTA sang Aviasales, disclosure và analytics |
| P4        | Chưa bắt đầu       | Mở rộng pSEO có kiểm soát từ tập thị trường đã chứng minh giá trị                           | Coverage, quality, indexability, cost và freshness gate hoạt động ở quy mô production          |
| P5        | Kế hoạch tương lai | Tích hợp Live Metasearch Engine đa nhà cung cấp (Yêu cầu traffic ≥ 50.000 MAU)              | Tích hợp Aviasales/Kiwi Search API khi website đủ điều kiện traffic và được cấp quyền live API |

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
10. **Homepage phân phối về canonical:** `From + To` được resolve bằng entity canonical phía máy
    chủ và điều hướng đến Route Page đã xuất bản. Query chưa resolve, route chưa xuất bản và search
    theo ngày không được sinh URL pSEO hay thay thế nội dung Route Page.

## 5. Thước đo thành công tổng thể

Lộ trình MVP thành công khi:

- Người dùng có thể mở trang thành phố hoặc sân bay đã xuất bản và hiểu các mẫu tuyến bay thẳng hiện
  có (Route Explorer).
- Người dùng có thể chọn `From + To` trên homepage và đến đúng Route Page canonical (hiển thị bay thẳng
  hoặc các trạm nối chuyến 1–2 stops), hoặc nhận fallback hữu ích khi city pair chưa có trang được xuất bản.
- Người dùng có thể xem giá vé ước tính gần đây và chuyển tiếp an toàn tới đối tác liên kết
  (Travelpayouts/Aviasales) để hoàn tất đặt chỗ.
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

## 8. Kế hoạch phân tầng dữ liệu và mở rộng Route Explorer

Kế hoạch chi tiết nằm tại `docs/product/city-hub-provider-and-commercial-expansion-plan.md`.

- **P0A/P0B**: Giữ provider-neutral contract, fixture và staging `noindex`.
- **P1 (Reference Data)**: Dùng OurAirports cho reference data (country, city, airport, coordinates) có provenance và quyền rõ ràng.
- **P2 (Route Explorer & Schedule Graph)**: Dùng **AeroDataBox (qua API.market)** theo cơ chế Batch Ingestion định kỳ để nạp mạng lưới đường bay thẳng (`/airports/iata/{iata}/routes/direct`) và lịch bay định kỳ. Postgres xây dựng đồ thị kết nối 0–3 stops phục vụ ma trận trang pSEO (Airport Hub, City Hub, Route A $\to$ B) theo phong cách FlightConnections.
- **P3 (Commercial & Fare Observation)**: Dùng **Travelpayouts Data API v3** làm nguồn quan sát giá vé gần đây (cached fares 2–7 ngày) và luồng Affiliate Handoff an toàn sang chiến dịch Aviasales; không dùng Travelpayouts làm nguồn xây dựng mạng lưới đường bay.
- Module fare/affiliate luôn optional; City Hub, Airport Hub và pSEO core vẫn render đầy đủ đồ thị tuyến bay khi commercial module vắng mặt.

## 9. Bổ sung phạm vi pSEO theo phase

### P0A/P0B — Khoá contract và rebuild foundation

- Dọn frontend cũ; chỉ giữ app shell, Terms và các primitive dùng lại được cho tới khi contract mới
  có test.
- Chọn một public page contract và một route-search contract không có hậu tố `_v2`.
- Định nghĩa page read model cho Homepage, City Hub, Airport và Route gồm module order, UX copy,
  CTA, empty state, metadata, freshness, provenance và indexability.
- Homepage resolve một origin hoặc city pair canonical: chỉ có `From` mở City Hub, còn `From + To`
  mở Route Page. Không render danh sách kết quả route, không gọi provider và không tạo query URL
  indexable tại homepage.
- City Hub, Airport Page và Route Page dùng chung compact route switcher trong header. Control này
  chỉ điều hướng đến City Hub/Route Page canonical hoặc fallback discovery; không prefill hay bắt đầu
  dated live search, không thay hero và không tạo query URL.
- Khoá Airport Page theo intent journey-first: orientation, arrival, transport, departure rồi mới
  đến verified direct flights hai chiều; không tái sử dụng featured-route payload cũ.
- Fixture chỉ chứng minh contract và luôn `noindex`; không được xem là content coverage production.

### P1 — Content foundation và dữ liệu tham chiếu production

- Nhập country, region, city, airport, timezone và city-airport grouping có quyền sử dụng rõ ràng từ OurAirports.
- Cấp dữ liệu canonical cho autocomplete `From`/`To` và resolver city pair; chọn airport phải được
  quy về city hoặc airport-page identity đã được duyệt.
- Xây workflow biên tập/kiểm duyệt cho airport orientation, arrival/departure steps, directional
  transport, parking, terminal/facility, lounge, notice, FAQ và internal link.
- Tính content completeness theo page type; page thiếu dữ liệu không được tự động index.

### P2 — Route Explorer, Schedule Graph và pSEO Matrix

- Ingest mạng lưới chặng bay thẳng (Direct Routes) từ AeroDataBox (qua API.market) vào Postgres `public.direct_flight_routes`.
- Xây dựng Route Graph Engine trong Postgres hỗ trợ tìm kiếm:
  1. Bay thẳng (0-stop) kèm hãng khai thác (operating airlines) và lịch bay định kỳ.
  2. Nối chuyến 1–2 điểm dừng (1-stop, 2-stops connection hubs qua Top 50 Hubs) kèm thời gian bay ước tính.
- Tự động sinh và tối ưu ma trận trang pSEO chuẩn FlightConnections:
  - **Airport Hub Page**: Tất cả các điểm đến bay thẳng từ sân bay, phân nhóm theo quốc gia/khu vực.
  - **Route Page (A $\to$ B)**: Chi tiết chặng bay thẳng, các phương án nối chuyến qua Hubs, lịch bay trong tuần.
  - **City Hub Page**: Tổng hợp các sân bay phục vụ thành phố và mạng lưới điểm đến.
- Đảm bảo chất lượng SEO: Page chỉ index khi có dữ liệu route thật, provenance rõ ràng và canonical identity.

### P3 — Tích hợp thương mại và quan sát giá vé (Travelpayouts Data API)

- Tích hợp **Travelpayouts Data API v3** làm tầng dữ liệu thương mại (Monetization Layer).
- Cơ chế On-demand Cache-aside: Lưu giá vé quan sát gần nhất (`observed_amount`) vào `public.flight_route_prices` (TTL tối đa 7 ngày, cron refresh ngày thứ 6) mà không làm chậm SSR hay vỡ trang khi API lỗi.
- Triển khai luồng Affiliate Handoff an toàn: Tạo link CTA dẫn sang trang đối tác Aviasales (`https://www.aviasales.com/search/...`) kèm Partner Marker & SubID để người dùng kiểm tra giá thực tế và đặt vé.
- Bật kill switch cho commercial module: Nếu Travelpayouts gặp sự cố, toàn bộ đồ thị Route Explorer và trang pSEO vẫn hoạt động bình thường.
- Tuyệt đối không yêu cầu live booking polling hoặc live metasearch trong phase này.

### P4 — Mở rộng pSEO có kiểm soát

- Chỉ mở rộng page count khi query demand, unique value, content completeness và freshness đạt ngưỡng.
- Publication gate tự động `noindex` page mỏng, trùng lặp, stale, thiếu quyền nguồn hoặc không có route.
- Theo dõi crawl/index coverage, organic landing quality, filter usage, affiliate conversion, ad impact,
  provider cost và stale-data SLO theo page cohort.
- Đo funnel `homepage From`, `homepage From + To`, Route Page reached và fallback; dữ liệu demand
  này chỉ dùng để đánh giá cohort pSEO, không tự tạo hoặc index URL từ mọi truy vấn.
- Rollout theo country/market cohort và có rollback về publication version gần nhất.

### P5 — Live Metasearch Engine (Kế hoạch tương lai)

- Điều kiện tiên quyết: Website đạt tối thiểu **50.000 MAU** và được phê duyệt cấp phép **Aviasales Search API** hoặc **Kiwi Search API**.
- Tích hợp Live Search orchestration, polling kết quả tìm kiếm thời gian thực theo ngày cụ thể (`/api/live-flights/search`).
- Tách bạch rõ vé nối chuyến tự bảo vệ (`protected connection`) vs tự chuyển chặng (`self_transfer`) từ dữ liệu provider thời gian thực.
- URL tìm kiếm live luôn được gắn cờ `noindex`, hoàn toàn tách biệt với các trang pSEO tĩnh.

## 10. Chiến lược kiểm soát rủi ro cốt lõi (Core Risk Mitigations)

Nhằm đảm bảo sản phẩm vượt qua các rủi ro vận hành và thuật toán tìm kiếm, Tripways áp dụng 5 biện pháp phòng vệ:

1. **Chống Thin Content & Đáp ứng chuẩn Google Helpful Content (HCU)**:
   - Không sinh trang rỗng/trùng lặp. Mỗi trang Route Page được làm giàu bằng **dữ liệu định lượng độc đáo**:
     - Khoảng cách bay thực tế ($km$), thời gian bay trung bình, số chuyến/tuần.
     - Lịch bay chi tiết theo ngày trong tuần (Day-of-Week matrix).
     - So sánh chi tiết giữa các lựa chọn: Hãng bay thẳng vs Các phương án nối chuyến qua Hubs.
   - **Quality Gate**: Tự động đánh dấu `noindex` những trang thiếu dữ liệu lịch bay hoặc có độ tin cậy thấp.

2. **Tối ưu hiệu năng Graph & Chống nghẽn Database**:
   - Mạng lưới ~70.000 chặng bay thẳng được lập chỉ mục (B-Tree + Compound Index trên `origin_iata`, `destination_iata`).
   - Thuật toán nối chuyến 1–2 stops được tối ưu hóa: Chỉ tìm điểm quá cảnh qua **Top 50 Major Global Hubs** (DOH, SIN, DXB, BKK, IST, HND, LHR, FRA...).
   - **Pre-computed Read Models**: Materialize sẵn kết quả cho các cặp thành phố phổ biến vào bảng `flight_route_options` để thời gian phản hồi luôn $< 10\text{ms}$.

3. **Tối ưu tỷ lệ chuyển đổi Affiliate (Handoff CTR)**:
   - Chuyển đổi từ mô hình đặt 1 nút CTA duy nhất sang **Contextual In-line CTAs**: Gắn nút _"Kiểm tra giá hãng này"_ bên cạnh từng phương án bay thẳng và từng trạm dừng nối chuyến.
   - Hiển thị rõ giá tham khảo quan sát gần nhất (`observed_amount`) để kích thích người dùng click kiểm tra giá live trên Aviasales.

4. **Đồng bộ chu kỳ đổi mùa bay IATA (Seasonality Sync)**:
   - Ngành hàng không thay đổi lịch bay 2 lần/năm: Mùa hè (Cuối tháng 3) và Mùa đông (Cuối tháng 10).
   - Ingestion cron chạy định kỳ **1 tháng / 1 lần** (Batch Ingestion cho top 500 sân bay) và kích hoạt **Full Sync bổ sung vào tuần cuối tháng 3 và tháng 10** để cập nhật kịp thời đường bay mùa vụ.

5. **Chiến lược dữ liệu Hybrid tối ưu chi phí ($5 - $20/tháng)**:
   - **OurAirports (Free 100%)**: Làm chân đế cho toàn bộ phân cấp địa lý (Country $\to$ Region $\to$ City $\to$ Airport).
   - **AeroDataBox (API.market)**: Dành trọn vẹn 100% quota API cho Direct Routes & Schedules. Tuyệt đối không lãng phí quota vào việc lấy thông tin sân bay/tọa độ đã có trong OurAirports.

## 11. Mô hình Doanh thu 4 Tầng (Monetization Engine — RPM $25 – $40+)

Thay vì chỉ dựa vào hoa hồng vé máy bay mỏng (1%–1.5%), Tripways triển khai tháp doanh thu 4 tầng:

1. **Flight Affiliate (Volume)**: Travelpayouts / Aviasales, Skyscanner, Trip.com (\$1 – \$3 / booking).
2. **Airport Ground Transfers (High Margin)**: Welcome Pickups, GetYourGuide, Klook, 12Go (**8% – 12%** giá trị đơn, \$4 – \$10 / cuốc xe) trên Airport Hub & Route Planning Grid.
3. **Travel Essentials (High EPC)**: Airalo / Nomad (eSIM: 15% – 25%), Priority Pass / Plaza Premium (Lounge: \$5 – \$12 / pass), SafetyWing (Bảo hiểm du lịch) trên module `SponsoredTravelServices` và `LoungeUtility`.
4. **Programmatic Display Ads**: Mediavine Journey / Raptive khi đạt mốc traffic (\$15 – \$35 RPM) tại các vị trí Sticky Sidebar, In-feed Native Cards, và Mobile Sticky Bottom.

## 12. Chiến lược Tăng trưởng pSEO & Cỗ máy Backlink B2B2C

1. **3 Định dạng trang pSEO mở rộng**:
   - **Hub-to-Region (`/flights-from/{city}/to/{region}`)**: vd: `/flights-from/bangkok/to/europe` phục vụ intent tìm kiếm khu vực điểm đến.
   - **Airline Hub Matrix (`/airlines-at/{airport}/{airline}`)**: vd: `/airlines-at/bkk/emirates` phục vụ khách trung thành liên minh bay.
   - **Airport Layover Guides (`/airports/{airport}/transit-guide`)**: vd: `/airports/doh/layover-guide` tối ưu chuyển đổi phòng chờ và tour trung chuyển.
2. **Embed Route Map Widget (Zero-cost Backlinks Engine)**:
   - Cung cấp iframe nhúng bản đồ mạng bay tương tác cho travel bloggers, khách sạn và báo chí kèm backlink do-follow tự nhiên: _"Interactive Flight Map provided by Tripways"_.
3. **Tính năng Viral "Weekend Direct Getaways"**:
   - Bộ lọc khám phá: _"Từ thành phố của tôi, có thể bay thẳng đi đâu dưới 3 tiếng với giá ước tính dưới $100?"_.
