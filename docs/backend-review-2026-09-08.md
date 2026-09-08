# Backend Review — 2026-09-08

**Kết luận: chưa đủ ổn để đưa pipeline data/cache hiện tại vào production.** Có lỗi chặn runtime, lỗi cache concurrency/expiry và lỗi làm sai hoặc mất liên kết dữ liệu. 160 test hiện có pass nhưng không chứng minh được các ranh giới Edge ↔ RPC ↔ schema hoạt động đúng.

Phạm vi: `tripways-backend`, gồm schema/migration, RPC, Edge entrypoints/handlers/providers, ingestion, read models, publication, cache, quyền truy cập, seed/content tooling và verification scripts. Không review toàn bộ frontend, không gọi provider trả phí, không deploy. DB local chỉ được truy vấn với `default_transaction_read_only=on`; không reset, không chạy ingestion/publication/purge trên dữ liệu hiện tại. Chỉ thêm báo cáo này, không sửa implementation.

P1 = cần xử lý trước khi bật tính năng liên quan/production. P2 = lỗi cần sửa hoặc giới hạn cần giải quyết khi vận hành. Các luồng price cache hiện `enabled = false`; airport cache và ingestion routes chưa có mapping entrypoint tương ứng trong config. Những lỗi ở các luồng này là blocker khi kích hoạt, không phải khẳng định chúng đang gây sự cố production.

## Findings

### 01. [P1] Cache gọi RPC trong schema không được expose

Vị trí: [price handler:47](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/flight/route-cache/handler.ts:47), [airport handler:47](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/flight/airport-routes-cache/handler.ts:47), [config:6](/Users/winn/Documents/Tripways/tripways-backend/supabase/config.toml:6).

Cả hai handler dùng `client.schema('admin').rpc(...)`, nhưng Data API chỉ expose `public`, `graphql_public`. Service-role có quyền SQL không đồng nghĩa schema được PostgREST expose. Theo cấu hình repo, yêu cầu bị chặn trước khi acquire lease. Đã đối chiếu [tài liệu Supabase](https://supabase.com/docs/guides/api/using-custom-schemas); chưa gọi HTTP vào endpoint cache.

Hướng sửa: giữ `admin` private; tạo public RPC wrapper `SECURITY INVOKER`, chỉ grant `service_role`, gọi hàm private. Đổi handler từ `.schema('admin').rpc(...)` sang `.rpc(...)` tên wrapper. Không mở toàn bộ `admin` để chữa lỗi transport.

### 02. [P1] SQL publish giá dùng cột không tồn tại

Vị trí: [rpc_publish_price_observations:39](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:39), [data_sources:6](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/schema/flight_routing/data_sources.sql:6).

Hàm tìm `provider_code`, rồi fallback INSERT `provider_code, source_type, is_active`. Bảng thực tế chỉ có `id, code, name, created_at, updated_at`. Cả source và migration chứa lỗi; schema DB local cũng xác nhận không có các cột đó. Vì SELECT này nằm trước mọi nhánh xử lý, cả publish có giá lẫn empty đều không hoạt động nếu gọi tới SQL này.

Sửa lookup theo `code`; nguồn phải được đăng ký và kiểm tra trước khi publish. Thêm integration test thực thi RPC với schema được dựng từ migration, thay vì mock kết quả thành công.

### 03. [P1] Autocomplete RPC không đúng envelope của Edge

Vị trí: [rpc_suggest_locations:137](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/route_discovery/rpc_suggest_locations.sql:137), [rpc-envelope:10](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/_shared/contracts/rpc-envelope.ts:10), [handler:7](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/location-suggest/handler.ts:7).

Cả nhánh nearby và query trả `{data: ...}`. Shared handler bắt buộc `error: null` và `meta.data_version`. Đã lấy kết quả thật của `rpc_suggest_locations({query:'HAN',limit:1})` từ DB, truyền qua validator thật: nhận `ERR_LOCATION_SUGGEST_CONTRACT`. Test hiện tại tự thêm meta/error vào mock nên pass sai ranh giới tích hợp.

Sửa contract SQL/transport thống nhất, quyết định version thích hợp cho master data. Test handler với response RPC thật. Mapping deploy `location-suggest` cũng cần được khai báo vì code đang nằm trong cây `v1`, không phải entrypoint mặc định.

### 04. [P1] Lease không chống được nhiều request refresh cùng lúc

Vị trí: [price acquire:78](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_acquire_price_refresh_lease.sql:78), [airport acquire:62](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_acquire_airport_route_refresh_lease.sql:62).

Request A tạo lease `refreshing`. Request B gặp conflict nhưng giữ nguyên lease A; sau đó cả hai đều thỏa `status='refreshing' AND lease_expires_at >= now()` và nhận `lease_acquired`. Khóa row của UPSERT không giải quyết việc xác định ai là chủ lease. Hậu quả: provider bị gọi nhiều lần, phí/quota tăng, worker chậm có thể ghi đè dữ liệu mới.

Sửa bằng conditional acquisition chỉ trả row cho người thắng, sinh token cho mỗi lần acquire, yêu cầu token khi finalize/publish. Lease ID hiện chỉ là ID row, không được handler gửi lại để kiểm chứng quyền hoàn tất. Cần test nhiều kết nối DB đồng thời và worker cũ trả kết quả sau khi lease đã cấp cho worker mới. Đây là kết luận từ SQL, chưa thực hiện stress test trên DB dùng chung.

### 05. [P1] Lease hoàn tất không thể refresh lại sau expiry/cooldown

Vị trí: [price acquire:82](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_acquire_price_refresh_lease.sql:82), [airport acquire:66](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_acquire_airport_route_refresh_lease.sql:66), [airport finalize:40](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_finalize_airport_route_refresh_lease.sql:40).

Publish/finalize đặt `lease_expires_at = NULL`. Acquire chỉ chuyển trạng thái nếu `lease_expires_at < now()`, biểu thức với NULL không đúng. Sau hết cooldown, `empty/failed` tiếp tục giữ nguyên, rơi xuống trả `refreshing`; `fresh` cũng bị kẹt sau khi dữ liệu hết TTL. UI có thể loading mãi mà không worker nào refresh.

Đã kiểm chứng nhánh CASE tương ứng bằng SELECT read-only. Sửa state transition dựa trên cả trạng thái, cooldown và expiry NULL; tách `busy` thực sự với trạng thái chưa có worker. Test fresh→expired, empty→hết cooldown, failed→retry.

### 06. [P1] Cache toàn bộ điểm đến không có uniqueness hiệu lực

Vị trí: [route_price_cache_leases:22](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/schema/ingestion/route_price_cache_leases.sql:22).

`destination_iata` nullable trong UNIQUE composite. Request chỉ có origin dùng destination NULL; PostgreSQL mặc định cho phép nhiều row như vậy nên `ON CONFLICT` không bắt cùng scope. Mỗi lần có thể tạo lease mới, bypass cooldown và tăng bảng lease. Constraint DB local xác nhận đang là UNIQUE thông thường.

Sửa thành `UNIQUE NULLS NOT DISTINCT` trên PostgreSQL 17 hoặc scope key chuẩn hóa không NULL. Cơ chế này được xác nhận trong [PostgreSQL 17 docs](https://www.postgresql.org/docs/17/indexes-unique.html). Cần dọn trùng có kiểm soát trước khi đổi constraint nếu đã phát sinh dữ liệu.

### 07. [P1] Ingestion/cache không cập nhật read model; TTL không được bảo đảm ở lúc đọc

Vị trí: [ingest routes:118](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/ingest_direct_flight_routes_batch.sql:118), [publish prices:146](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:146), [rpc_get_page:69](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/shared/rpc_get_page.sql:69), [refresh_route_search_options:63](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql:63).

Cache ingestion chỉ ghi bảng canonical và lease. Không có bước publish read model trong các flow này hoặc cron hiện tại. Page/search đọc publication đã materialize, không đọc các thay đổi vừa ingest. Vì vậy UI có thể nhận cache `fresh` rồi reload vẫn thấy dữ liệu cũ/loading.

`valid_until` của giá và TTL route chỉ được kiểm tra lúc build projection/page. Sau đó snapshot vẫn được phục vụ dù giá/route hết hạn hoặc bị purge khỏi bảng gốc. Giá trong search projection còn không giữ expiry để kiểm tra lúc đọc. Affiliate RPC kiểm tra expiry riêng, nên có thể hiển thị giá rồi handoff thất bại.

Cần hoàn thiện chuỗi ingest→validate→publish→invalidate và cơ chế hết hạn độc lập với việc có request/provider thành công. Với giá động nên cân nhắc đọc bổ sung có TTL riêng để không phải rebuild toàn mạng cho từng giá. Không thể chữa vấn đề này chỉ bằng thêm Redis/CDN.

### 08. [P1] Import OurAirports qua Edge có thể xóa liên kết airport→city

Vị trí: [provider:85](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/base-data/providers/ourairports-provider.ts:85), [provider:172](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/base-data/providers/ourairports-provider.ts:172), [publish_base_data_batch:535](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/publish_base_data_batch.sql:535).

Adapter live trả `cities: []`, mọi airport có `citySourceId: null`. Publisher khởi tạo city ID NULL rồi UPSERT `city_id = EXCLUDED.city_id`. Nếu import snapshot CSV mới sau khi đã dùng local dataset đầy đủ, các liên kết city hiện có bị ghi đè thành NULL. Route projection INNER JOIN cities sẽ loại các route đó; price publisher cũng skip airport không có city.

DB local hiện có 3.210 airport nguồn OurAirports đã gắn city; đây là phạm vi có thể bị ảnh hưởng, không phải số đã bị mất. Không chạy ingestion để thử trên dữ liệu này. Sửa adapter dùng cùng canonical mapping hoặc quy định rõ dữ liệu thiếu không được xóa mapping. Muốn xóa phải có tín hiệu tường minh, không suy từ trường chưa được provider cung cấp.

### 09. [P1] Chưa có hàng rào tách fixture và nguồn được phép publish production

Vị trí: [data_sources](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/schema/flight_routing/data_sources.sql:6), [ingest routes:34](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/ingest_direct_flight_routes_batch.sql:34), [publication:40](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/shared/publish_read_model_version.sql:40), [base request:12](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/base-data/request.ts:12).

Data source hiện chỉ lưu định danh; route ingestion tự đăng ký nguồn lạ, projection nhận mọi route active/fresh. Production indexability chỉ dựa vào tham số `production`, trạng thái trang, content reviewed và tồn tại route. Không kiểm tra loại fixture, quyền nguồn hoặc phê duyệt nguồn như rule yêu cầu. `providerMode` và `sourceCode` của base ingestion cũng không bị ràng buộc với nhau.

DB local đang có 16 route fixture cùng 477 route AeroDataBox; publication hiện là development_fixture nên đây chưa phải sự cố SEO production. Nhưng gọi publication production với trang đủ điều kiện có thể đưa fixture vào search/SEO, và metadata đã mất lineage sau khi projection.

Hướng sửa ranh giới bảo vệ:

```text
Trước: active + fresh + caller chọn production → eligible
Sau: source được allowlist + được duyệt cho môi trường + không fixture
     + fresh + content reviewed → eligible
```

Không cần thiết kế hệ thống quyền tổng quát: tối thiểu ràng buộc source/mode/environment và fail closed khi nguồn chưa được duyệt. Cần test fixture không lọt production ngay cả khi worker gọi sai tham số.

### 10. [P1] Lịch và thông số chưa biết bị chuyển thành thông tin có vẻ chắc chắn

Vị trí: [schedule intersection:35](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/route_discovery/calculate_route_schedule_intersection.sql:35), [AeroDataBox parser:26](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/providers/aerodatabox-provider.ts:26).

Đã chạy DB: `calculate_route_schedule_intersection(ARRAY[1], ARRAY[2])` trả `{1}` dù giao rỗng. Missing days bị thành cả tuần; missing duration thành 120 phút. Projection dựng one-stop dùng minimum transit như thời gian layover mà không có lịch giờ đến/đi thực tế. Điều này có thể biến kết nối suy đoán thành hành trình có lịch và duration cụ thể; qua đêm/múi giờ cũng chưa được mô hình hóa.

Sửa giao rỗng thành rỗng và loại hoặc gắn trạng thái chưa xác minh; giữ unknown cho dữ liệu thiếu. Chỉ có graph connectivity thì trả kết nối tham khảo, không mô tả là lịch bay đã kiểm chứng. Test ngày rời nhau, lịch thiếu, chặng qua ngày và hub inactive.

### 11. [P1] Giá có thể bị gộp sai currency, market, airline và loại hành trình

Vị trí: [city price aggregation:165](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/city/build_city_page_payload.sql:165), [price upsert key:127](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:127), [projection price selection:63](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql:63).

City payload lấy `min/max(price_amount)` và `min(price_currency)` độc lập. Ví dụ 100 USD và 80 GBP bị gộp thành 80–100 GBP. Projection chọn giá không lọc market/currency; one-stop chỉ match cặp sân bay + số stop, không match hub/airline của route cụ thể.

Price `source_record_id` chỉ gồm origin, destination, departure date, currency; hai market/hãng/return-date/transfer khác nhau có thể trùng key. Nhánh UPDATE chỉ sửa giá/timestamp/path, giữ lại market/airline/direct/duration của record trước. Mọi observation còn bị gắn `one_way` kể cả có return date.

Sửa identity theo offer thực của provider và đủ chiều nghiệp vụ; cập nhật metadata nhất quán. Chọn một market/currency rõ ràng hoặc group theo currency; không gán giá one-stop cho itinerary chưa chứng minh cùng đường bay. Test cùng ngày khác hãng, direct vs connecting, return vs one-way, nhiều market/currency.

### 12. [P1] Cron hiện chưa nối được với handler triển khai

Vị trí: [cron config:53](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/operations/configure_ingestion_crons.sql:53), [route ingestion entrypoint:6](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/index.ts:6), [cache request:15](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/flight/route-cache/request.ts:15), [config](/Users/winn/Documents/Tripways/tripways-backend/supabase/config.toml).

Cron gọi `/functions/v1/ingestion/routes` và `/functions/v1/flight/route-cache`, trong khi cấu hình sử dụng slug phẳng như `flight-route-cache`; route cache đang disabled, ingestion routes chưa có mapping. Không có router trung gian trong repo cho các đường dẫn đó.

Ngay cả khi sửa URL, hai job Travelpayouts gửi `{mode:'warm_top_routes'}` và `{mode:'day6_active_refresh'}` nhưng parser không cho `mode` và yêu cầu origin. Đã chạy parser thật: cả hai báo `ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST`.

Route worker đọc `SERVICE_ROLE_KEY`, dùng cùng giá trị để xác thực và tạo DB client, trong khi cron gửi Vault `ingestion_worker_secret`; helper chuẩn dùng `SUPABASE_SERVICE_ROLE_KEY`. Với các secret tách riêng đúng thiết kế, yêu cầu không thể xác thực/call DB đúng. `all_eligible` được parser nhận nhưng execute không chọn airport cho scope này, dẫn tới success với 0 airport.

Sửa mapping endpoint, tách worker auth secret khỏi DB credential, implement scheduler fan-out có giới hạn/tiến độ hoặc bỏ job chưa hỗ trợ. Test payload job thật qua gateway tới RPC; không coi có row `cron.job` là job thành công.

### 13. [P1] Publication có thể thất bại dù có direct routes hợp lệ

Vị trí: [projection:167](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql:167), [publication:93](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/shared/publish_read_model_version.sql:93).

`ROW_COUNT` chỉ lấy sau INSERT one-stop, bỏ qua số direct routes vừa INSERT. Dataset có direct routes nhưng không có connecting route trả count 0; publisher đánh dấu `ERR_PUBLICATION_INCOMPLETE`, giữ bản cũ. Dataset rỗng thật cũng không thể publish để gỡ dữ liệu cũ, cần quyết định rõ chính sách empty publication.

Sửa đếm tổng direct+connecting hoặc count candidate. Test dataset chỉ có A→B, không hub; test toàn bộ nguồn hết hạn mà vẫn cần phục vụ trang với trạng thái unavailable.

### 14. [P2] Idempotent replay bị chuyển thành lỗi 500

Vị trí: [duplicate SQL:94](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/publish_base_data_batch.sql:94), [Edge result guard:77](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/base-data/index.ts:77).

Duplicate response thiếu `acceptedCount`, `rejectedCount`; guard yêu cầu cả hai. Response bị loại trước khi service/handler đi tới nhánh duplicate 409 đã viết sẵn. Đây là case thường gặp khi retry do mất kết nối sau commit.

Sửa SQL trả một envelope ổn định cho mọi trạng thái hoặc dùng discriminated union theo status. Test lặp cùng checksum/key bằng transport thật. Ngoài ra checksum live OurAirports chỉ hash CSV; thay denylist/filter với CSV không đổi vẫn bị coi duplicate, nên checksum xử lý cần bao gồm phiên bản filter/đầu vào chuẩn hóa.

### 15. [P2] Provider lỗi bị báo empty; finalize lỗi bị bỏ qua

Vị trí: [price handler:97](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/flight/route-cache/handler.ts:97), [airport handler:166](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/flight/airport-routes-cache/handler.ts:166), [AeroDataBox fetch:207](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/providers/aerodatabox-provider.ts:207).

Travelpayouts 401/429/timeout bị catch thành mảng rỗng, rồi negative-cache 6 giờ. Airport provider lỗi trả HTTP 200 empty; finalize RPC không kiểm tra error. `failure_code` DB giới hạn 50 ký tự nhưng handler gửi nguyên `Error.message`, dễ làm finalize tiếp tục thất bại với lỗi HTTP dài. Parse được N routes nhưng DB skip toàn bộ vẫn có thể báo fresh N routes vì dùng độ dài input thay vì upsert count.

Phân biệt `empty` đã xác nhận, `failed` tạm thời, `refreshing`, `fresh`, `stale`. Kiểm tra mọi RPC result, dùng error code chuẩn, trả retry time thích hợp. Provider HTTP error body không nên đi nguyên vào log/response; logger hiện redact context key nhưng không redact nội dung message/stack/DB details.

### 16. [P2] Price API trả khác contract giữa cache miss và hit; timestamp sai tên

Vị trí: [cold response:137](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/flight/route-cache/handler.ts:137), [warm response:39](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_acquire_price_refresh_lease.sql:39), [price timestamp:84](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:84).

Cold response trả provider observations camelCase và affiliatePath, không có opaque `observation_ref`; warm trả snake_case có reference. Client dùng observation handoff có thể chỉ hoạt động từ lần đọc sau. Cache lookup join airport qua city nên request LHR có thể lấy giá của LGW cùng city, trái identity cache theo airport.

Adapter xuất `foundAt`; SQL đọc `observedAt`, luôn fallback now. Đã chạy adapter thật xác nhận không có key observedAt. Observation cũ có thể bị làm sai tuổi dữ liệu; nếu expiry đã qua, batch có thể lỗi validity constraint. SQL còn default direct unknown thành true.

Sửa dùng một public DTO từ bản ghi đã publish cho cả cold/warm, lọc đúng airport IDs, giữ unknown và timestamps provider. Test giá cũ/expired, metro code không phải airport, nhiều sân bay cùng city và tất cả observation bị skip.

### 17. [P2] Payload trang không bị giới hạn; cache header chưa chứng minh hiệu quả

Vị trí: [city routes](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/city/build_city_page_payload.sql:210), [airport routes](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/airport/build_airport_page_payload.sql:103), [query handler:32](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/_shared/contracts/query-handler.ts:32), [cache headers:9](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/_shared/edge.ts:9).

City builder không dùng `destination_limit` được truyền vào, `routes` và featured destinations aggregate toàn bộ; airport cũng lấy mọi inbound/outbound option. DB local đo `octet_length(payload::text)`: Hà Nội 1.675 routes / 545.645 bytes; HAN 1.696 routes / 518.520 bytes. Đây là kích thước JSON text trong DB, không phải wire size sau nén. Khi graph tăng, publication và mỗi response tăng mạnh.

Cần page payload có giới hạn, số tổng và route query phân trang. Không cần tải toàn graph vào trang đầu. Route-search offset cursor cũng không gắn publication version; chuyển version giữa hai trang có thể lặp/mất kết quả.

Page/search/suggest chỉ nhận POST dù gắn `s-maxage=86400`. Chưa có bằng chứng CDN thực tế cache POST hoặc key theo body; không được coi header là đã có cache hit. Nếu cấu hình cache riêng, identity phải có body chuẩn hóa/locale/version và TTL phải không vượt expiry data. HTTP cache thực tế ở frontend/CDN nằm ngoài review này.

### 18. [P2] Rate limit và timeout chưa đủ bảo vệ pipeline khi scale

Vị trí: [memory limiter](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/_shared/rate_limit.ts:41), [airport provider:207](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/providers/aerodatabox-provider.ts:207), [route service](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/service.ts:67).

Rate limit lưu trong Map riêng mỗi worker; cold start/scale-out không chia sẻ quota, đạt maxEntries còn clear toàn bộ. Public cache route cho caller chọn nhiều scope, không có global provider budget. Query endpoint dùng service-role nhưng chưa có limiter tại handler. Không khẳng định x-forwarded-for giả mạo được qua gateway vì chưa kiểm chứng cấu hình proxy.

AeroDataBox fetch không có AbortSignal/timeout; batch xử lý tuần tự đến 80/1.000 airport, không checkpoint. Một request chậm có thể giữ cả job; runtime timeout dẫn tới import dở dang mà log không phản ánh job completion. Header idempotency của cron routes không được dùng.

```text
Trước: Map riêng mỗi worker + gọi provider không timeout
Sau: quota chung tại boundary gọi provider + lease đúng + timeout tổng
     + batch nhỏ có checkpoint/idempotency theo scope
```

Ưu tiên giới hạn ở gateway hoặc storage dùng chung sẵn có; thêm cảnh báo provider calls, 429, lease stuck, freshness lag và publication failures. Không cần thêm tầng cache mới trước khi sửa tính đúng của lease.

### 19. [P2] Verification hiện bỏ sót entrypoint lỗi và có script dùng chữ ký RPC cũ

Vị trí: [package scripts](/Users/winn/Documents/Tripways/tripways-backend/package.json:12), [ingestion entrypoint:42](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/index.ts:42), [DB client type](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/service.ts:7), [staging check](/Users/winn/Documents/Tripways/tripways-backend/scripts/check-staging-readiness.sh:53).

`pnpm edge:check` pass nhưng không bao gồm ingestion routes. Khi check thêm, TypeScript báo TS2345: Supabase RPC builder là thenable, không đáp ứng interface yêu cầu Promise đầy đủ (`catch`, `finally`, Symbol.toStringTag). Cần type đúng boundary và kiểm tra mọi entrypoint có thể triển khai.

Staging check gọi `has_function_privilege(...handoff(uuid)...)` nhưng function hiện nhận TEXT. DB local xác nhận `to_regprocedure(uuid)` NULL, signature TEXT tồn tại. Script có thể lỗi thay vì đưa kết luận readiness. Ngoài ra script chỉ kiểm tra job có tồn tại, không kiểm tra kết quả HTTP của cron.

### 20. [P2] Content tooling có thể đổi môi trường publication và phá tính tái tạo migration

Vị trí: [content generator](/Users/winn/Documents/Tripways/tripways-backend/content/generate_content_migration.ts:253), [migration generator:51](/Users/winn/Documents/Tripways/tripways-backend/scripts/regenerate-supabase-migrations.sh:51).

Content generator ghi đồng thời seed và migration, tự gắn `content_reviewed_at=now()`, rồi hard-code `publish_read_model_version('development_fixture')` dù cho phép `--db-url`. Chạy vào staging/production có thể đổi current publication về fixture/noindex; import nội dung chưa được review cũng tự vượt điều kiện editorial reviewed.

Migration editorial không thuộc 53 SQL source; migration generator xóa toàn bộ migration trước khi tái tạo nên file editorial này sẽ biến mất. Kết quả kiểm tra chỉ chứng minh 53 source hiện khớp 53 phần generated, không chứng minh toàn bộ migration có một nguồn duy nhất. Nội dung còn được seed lại nên có hai đường áp dụng.

Sửa content thành seed/operation riêng có environment rõ ràng, trạng thái reviewed là thao tác biên tập tường minh. Generator nên fail nếu publication response có error (psql thành công không có nghĩa RPC publish thành công). Không in dbUrl có password ra log. Không chạy các script này trong review.

### 21. [P2] Đổi tên city có thể làm thất bại toàn batch

Vị trí: [city upsert:389](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/publish_base_data_batch.sql:389), [city constraints](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/schema/flight_routing/cities.sql:24).

Publisher INSERT city với conflict target `(country_id, slug)` rồi mới UPDATE theo source ID. Khi cùng source_record_id đổi name dẫn tới slug mới, INSERT đụng UNIQUE `(source_id,source_record_id)` mà conflict target không bắt, nên rollback trước UPDATE. Tên Unicode không có ký tự ASCII cũng có thể tạo slug rỗng; trùng tên trong cùng quốc gia có thể bị gộp mất identity.

Sửa upsert theo source identity ổn định, xử lý slug/canonical redirect riêng và phát hiện collision rõ ràng. Test đổi tên/đổi country, dấu Unicode, hai city trùng tên, airport đổi IATA/ICAO và nguồn thứ hai nhập cùng airport.

## Tình huống vận hành cần có kiểm thử

| Tình huống                                                      | Kết quả cần bảo đảm                                                                             |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Nhiều request cùng airport/route chưa có cache                  | Một provider call cho scope; các request khác nhận busy/stale có thời điểm retry                |
| Origin-only, destination NULL                                   | Một lease duy nhất; cooldown có hiệu lực                                                        |
| Worker chết; worker cũ trả sau khi lease cấp lại                | Lease hết hạn được cấp lại; token cũ không ghi đè                                               |
| Empty/429/401/timeout/malformed JSON                            | Phân biệt empty đã xác nhận với lỗi tạm thời/cấu hình                                           |
| Provider trả một số airport/hãng chưa biết hoặc trả trùng route | Có accepted/rejected/skipped counts; không báo fresh theo input length                          |
| Snapshot mới thiếu route cũ                                     | Xác định snapshot đầy đủ hay partial; không coi partial là xóa và không giữ route đã hủy vô hạn |
| Giá hết hạn/chuyến đã khởi hành/provider bị ngừng               | Page/search/handoff nhất quán; không chỉ dựa vào timestamp cache                                |
| Nhiều currency/market/airline/return date                       | Không ghi đè identity, không gộp amount khác currency                                           |
| Hai sân bay cùng city, metro code LON/TYO                       | Resolve đúng city/airport; không lấy nhầm cache                                                 |
| OurAirports cập nhật mới hoặc đổi denylist                      | Không mất city mapping; checksum tính cả filter; anomaly có lối review/retry                    |
| Retry sau commit nhưng mất response                             | Trả kết quả idempotent đúng contract                                                            |
| Chỉ có direct route, zero route, hub inactive                   | Publication có chính sách rõ ràng; không để snapshot cũ tồn tại vô hạn                          |
| Publish giữa hai lần phân trang                                 | Cursor gắn version hoặc trả yêu cầu restart                                                     |
| Hàng nghìn airport/routes và nhiều request query                | Đo payload, p95 latency, query plans, thời gian rebuild, quota; kiểm chứng cache hit thực tế    |
| Fixture có mặt cùng dữ liệu thật                                | Production/publication/indexability chặn fixture độc lập với caller                             |
| Cron được schedule nhưng HTTP thất bại                          | Cảnh báo dựa trên HTTP/job result và freshness lag, không chỉ cron.job tồn tại                  |

## Verification thực hiện

- `deno test --config supabase/functions/deno.json --allow-read supabase/functions`: **160 passed, 0 failed**.
- `pnpm edge:check`: **pass** với danh sách entrypoint hiện tại.
- Check thêm `flight/route-cache/index.ts` và `ingestion/routes/index.ts`: **fail TS2345** tại routes index:42.
- `pnpm edge:fmt:check`: **pass**, 85 files.
- `pnpm format:check`: **fail**, 9 file content/generator. Không tự format.
- So khớp read-only: **53/53 SQL source** có mặt và nội dung khớp generated migration; editorial là migration thêm ngoài tập này.
- DB local PostgreSQL 17.6: **0 bảng public thiếu RLS**, **0 grant INSERT/UPDATE/DELETE trên bảng public cho anon/authenticated**, **0 public SECURITY DEFINER functions**. Đây là tín hiệu tốt, không thay thế toàn bộ privilege execution tests.
- DB local: 493 direct routes (477 AeroDataBox + 16 fixture), 2.697 connecting options và 493 direct options trong current version; current source_type là development_fixture. Không có raw routes quá 7 ngày hoặc expired price tại thời điểm đọc.
- Tái hiện thật: schedule `[1]∩[2]` trả `[1]`; autocomplete RPC result bị shared validator từ chối; parser từ chối cả hai cron mode; adapter thiếu observedAt và default lịch cả tuần/duration 120.
- Đo payload DB local như finding 17. Chưa benchmark network, CDN hoặc tải đồng thời.
- Kiểm tra tracked env: chỉ `.env.example`; scan mẫu secret thông dụng không thấy kết quả. Không quét toàn bộ lịch sử Git hoặc chứng nhận không có mọi loại secret.
- Git ban đầu sạch; Git chỉ dùng truy vấn. Không chạy script regenerate/reset/verify:p0a do chúng có xóa file và reset DB. Không chạy snippet có mutation trên DB dùng chung.

## Thứ tự xử lý đề xuất

1. Sửa blocker transport/schema/envelope: 01–03, 12, 19; thêm smoke test Edge→RPC thật.
2. Sửa lease atomicity, owner token, NULL uniqueness và expiry transitions: 04–06.
3. Bảo vệ data identity và môi trường: 08–11, 14, 16, 21.
4. Hoàn thiện publication/invalidation/TTL và empty publication: 07, 13.
5. Xử lý failure/retry/quota, giới hạn payload và tooling: 15, 17, 18, 20.

Các thay đổi SQL sau review cần sửa `sql_src`, tái tạo migration bằng workflow đã được cho phép và kiểm chứng trong DB test cô lập. Không chạy reset hoặc công cụ xóa file trên workspace hiện tại khi quy tắc cấm vẫn còn hiệu lực.

implemented: báo cáo review, kiểm tra tĩnh, test hiện có, kiểm chứng read-only DB và ranh giới contract; skipped: sửa code, reset DB, mutation tests, provider live, deploy và load test; add when: bắt đầu đợt sửa với môi trường test cô lập và bộ case ưu tiên ở trên.
