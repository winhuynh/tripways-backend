# 🚀 Tripways — Lộ trình Sản phẩm & Kế hoạch Từng Phase (Product Roadmap)

> **Mục tiêu cốt lõi:** Xây dựng nền tảng **Flight Route Explorer & Programmatic SEO (pSEO)** chất lượng cao theo mô hình của _FlightConnections / FlightsFrom_, kết hợp tầng thương mại **Travelpayouts Affiliate Handoff** để tối ưu hóa doanh thu hoa hồng với chi phí vận hành siêu thấp ($5 – $20/tháng).

---

## 🧭 Tổng quan Các Giai đoạn (Phases Overview)

| Giai đoạn          | Trọng tâm chính                  | Nguồn dữ liệu             | Kết quả đầu ra (Deliverables)                                                          |
| :----------------- | :------------------------------- | :------------------------ | :------------------------------------------------------------------------------------- |
| **P0 (P0A & P0B)** | **Nền tảng & Staging**           | Local fixtures            | App shell, Database schema, RLS, CI/CD, Staging `noindex`.                             |
| **P1**             | **Dữ liệu Địa lý & Sân bay**     | OurAirports (Free)        | Master database: Quốc gia, Thành phố, Sân bay, Tọa độ, Timezone.                       |
| **P2**             | **Route Explorer & pSEO Matrix** | AeroDataBox (API.market)  | Đồ thị mạng lưới đường bay thẳng (0-stop) & Nối chuyến (1–2 stops), Ma trận trang SEO. |
| **P3**             | **Thương mại & Giá vé Quan sát** | Travelpayouts Data API v3 | Cache giá vé quan sát (`observed_amount`), Nút CTA Affiliate Handoff sang Aviasales.  |
| **P4**             | **Scale pSEO có kiểm soát**      | Toàn bộ hệ thống          | Quét chất lượng index, mở rộng sitemap theo cohort thị trường, tối ưu chuyển đổi.      |
| **P5**             | **Live Metasearch Engine**       | Aviasales / Kiwi Search   | Live search theo ngày cụ thể (Yêu cầu traffic ≥ 50.000 MAU để được duyệt Search API).  |

---

## 📌 Chi tiết Kế hoạch Từng Phase (Phase Breakdown)

### 🔹 Phase 0: Kiến trúc nền tảng & Sẵn sàng Staging (P0A / P0B)

- **Mục tiêu:** Xây dựng khung kiến trúc sạch, phân quyền cơ sở dữ liệu và môi trường kiểm thử độc lập.
- **Các công việc chính:**
  - [x] Chuẩn hóa kiến trúc Supabase PostgreSQL, RLS (Row Level Security), phân quyền `service-role`.
  - [x] Xây dựng Contract chuẩn `rpc_get_page` và `rpc_search_routes`.
  - [x] Tạo fixture dữ liệu mẫu xác định cho quá trình phát triển (Development fixtures).
  - [ ] Triển khai môi trường Cloud Staging riêng tư, chặn bot (`noindex`).

---

### 🔹 Phase 1: Nền tảng Định danh Địa lý & Sân bay (Reference Data Foundation)

- **Mục tiêu:** Khởi tạo cơ sở dữ liệu địa lý toàn cầu mà không tốn chi phí API.
- **Nguồn dữ liệu:** **OurAirports CSV Dataset** (Public Domain / CC0).
- **Các công việc chính:**
  - [ ] Batch Ingestion dữ liệu từ `countries.csv`, `regions.csv`, `airports.csv`.
  - [ ] Lọc ~4.000 sân bay thương mại lớn (`large_airport`, `medium_airport` có `scheduled_service = yes`).
  - [ ] Chuẩn hóa phân cấp: `Country -> Region -> City (Municipality) -> Airport`.
  - [ ] Xây dựng bộ máy Autocomplete tìm kiếm sân bay/thành phố và phân giải URL canonical.

---

### 🔹 Phase 2: Route Explorer & Schedule Graph (Đồ thị Tuyến bay & pSEO)

- **Mục tiêu:** Xây dựng tính năng Khám phá đường bay & Sinh ma trận trang SEO như _FlightConnections_.
- **Nguồn dữ liệu:** **AeroDataBox (qua API.market)** — Chạy Batch Ingestion hàng tháng.
- **Các công việc chính:**
  - [ ] **Data Ingestion**: Viết script quét endpoint `/airports/iata/{iata}/routes/direct` cho Top 500 sân bay lớn nhất thế giới, lưu vào `public.direct_flight_routes`.
  - [ ] **Route Graph Engine (PostgreSQL RPC)**:
    - Truy vấn bay thẳng (0-stop): Liệt kê các hãng hàng không đang khai thác (`operatedBy`).
    - Truy vấn nối chuyến (1–2 stops): Tự động tìm các trạm trung chuyển (Layover Hubs) qua Top 50 Global Hubs (`SIN`, `DOH`, `DXB`, `BKK`, `IST`, `HND`...).
    - Tính toán khoảng cách bay ($km$) và thời gian bay ước tính.
  - [ ] **Ma trận Trang pSEO (Landing Pages Matrix)**:
    - **Airport Hub Page** (`/airports/[iata]`): Bản đồ trực quan tất cả tuyến bay thẳng từ sân bay.
    - **Route Page** (`/flights/from-[origin]-to-[destination]`): Chi tiết bay thẳng, lịch bay trong tuần (Day-of-Week matrix), các phương án nối chuyến.
    - **City Hub Page** (`/cities/[slug]`): Tổng hợp mạng lưới đường bay của các sân bay trong cùng thành phố.
  - [ ] **Chống Thin Content (Google HCU)**: Cài đặt Quality Gate — chỉ lập chỉ mục (`index`) những trang có dữ liệu lịch bay thực tế và định lượng đầy đủ.

---

### 🔹 Phase 3: Tầng Thương mại & Giá vé Quan sát (Travelpayouts Data API & Affiliate Handoff)

- **Mục tiêu:** Tạo doanh thu từ hoa hồng đặt vé (Affiliate Marketing) mà không làm chậm hệ thống và không yêu cầu điều kiện traffic ngặt nghèo.
- **Nguồn dữ liệu:** **Travelpayouts Data API v3** (Cached price observations từ lịch sử tìm kiếm 2–7 ngày).
- **Các công việc chính:**
  - [ ] **On-demand Cache-aside**: Khi người dùng vào trang Route, kiểm tra cache giá vé trong Postgres (`flight_route_prices`). Nếu cache miss, gọi Edge Function lấy giá vé quan sát gần nhất (`observed_amount`).
  - [ ] **Contextual In-line CTAs**: Đặt nút _"Kiểm tra giá vé"_ bên cạnh từng hãng bay thẳng và từng chặng nối chuyến.
  - [ ] **Affiliate Handoff Gateway**: Server tạo URL chuyển tiếp an toàn (`/v1/flight/affiliate-handoff`) kèm Marker & SubID sang trang tìm kiếm Aviasales (`https://www.aviasales.com/search/...`).
  - [ ] **Kill Switch & Fallback**: Nếu API giá vé lỗi, toàn bộ đồ thị tuyến bay và trang pSEO vẫn hoạt động bình thường 100%.

---

### 🔹 Phase 4: Mở rộng pSEO & Tối ưu Chuyển đổi (Controlled Scale & Growth)

- **Mục tiêu:** Mở rộng quy mô lập chỉ mục Google Search và tối ưu hóa doanh thu.
- **Các công việc chính:**
  - [ ] Mở Sitemap theo từng nhóm thị trường (Market Cohorts), bắt đầu với 1.000 routes phổ biến nhất.
  - [ ] Theo dõi các chỉ số SEO qua Google Search Console: Indexation Rate, Impressions, Organic Clicks.
  - [ ] Tối ưu hóa phễu chuyển đổi: Đo lường Outbound CTR (tỉ lệ click sang đối tác) và EPC (Earnings Per Click).
  - [ ] Lên lịch Ingestion đồng bộ đổi mùa bay IATA (cuối tháng 3 và cuối tháng 10).

---

### 🔹 Phase 5: Live Metasearch Engine (Trải nghiệm Tìm kiếm Trực tiếp theo ngày)

- **Mục tiêu:** Cung cấp trải nghiệm tìm kiếm vé live real-time khi trang đã có lượng truy cập lớn.
- **Điều kiện tiên quyết:** Đạt tối thiểu **50.000 MAU** và được phê duyệt cấp phép **Aviasales Search API** hoặc **Kiwi Search API**.
- **Các công việc chính:**
  - [ ] Xây dựng dịch vụ Live Search Orchestration (`POST /api/live-flights/search`) và polling trạng thái.
  - [ ] Chuẩn hóa kết quả tìm kiếm thời gian thực (normalized short-lived offers).
  - [ ] Phân định rõ bảo vệ nối chuyến (`protected connection`) vs tự chuyển chặng (`self_transfer`).
  - [ ] Đảm bảo toàn bộ bề mặt kết quả tìm kiếm theo ngày đều mang cờ `noindex`.

---

## 🛡️ 5 Biện pháp Kiểm soát Rủi ro Cốt lõi (Risk Mitigations)

1. **Tránh phạt Thin Content (Google HCU)**: Bắt buộc mỗi trang sinh tự động phải có dữ liệu định lượng độc đáo (khoảng cách, giờ bay, ngày bay trong tuần, ma trận so sánh hãng).
2. **Hiệu năng Database**: Giới hạn tìm kiếm nối chuyến qua Top 50 Hubs lớn và Materialize sẵn các cặp tuyến hot vào `flight_route_options` (Query time $< 10\text{ms}$).
3. **Tối ưu Click Affiliate**: Đặt nút CTA theo ngữ cảnh từng hàng chặng bay thay vì chỉ 1 nút chung chung.
4. **Đồng bộ Lịch đổi mùa IATA**: Chạy Batch Sync bổ sung vào cuối tháng 3 (Summer Schedule) và cuối tháng 10 (Winter Schedule).
5. **Chiến lược Hybrid Data tiết kiệm**: Dùng OurAirports miễn phí 100% cho Sân bay/Thành phố $\to$ Dành trọn vẹn 100% quota AeroDataBox cho Tuyến bay.
