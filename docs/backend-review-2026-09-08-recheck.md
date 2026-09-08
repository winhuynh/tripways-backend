# Backend Review — Recheck 025ff51

**Kết luận: nhiều lỗi cũ đã được sửa trong source, nhưng chưa thể coi backend đã ổn. Có 2 blocker SQL mới, cơ chế token lease chưa bảo vệ thao tác ghi, cron giá vẫn không thực thi được và publication/TTL vẫn chưa nối đầy đủ.**

Baseline: `025ff51084d6fe00d3650f17cdafcae1578e757b`, ngày 2026-09-08. Đối chiếu lại 21 mục của báo cáo đầu, source/migration hiện tại và các entrypoint đã sửa. Chỉ thay đổi tài liệu review; không sửa implementation, không reset/migrate DB hoặc gọi provider thật.

**Phân biệt source với runtime:** DB local vẫn có `data_sources` chỉ gồm 5 cột cũ; chỉ có `publish_read_model_version(text)`; autocomplete chưa có envelope mới; hàm giao lịch vẫn trả `{1}` cho `[1]` và `[2]`. Vì vậy DB này chưa phản ánh bản sửa hiện tại. Không dùng kết quả DB cũ để tuyên bố bản sửa mới đã chạy thành công.

## Findings ưu tiên

### R1. [P1] City builder mới không chạy được vì aggregate lồng nhau

Vị trí: [build_city_page_payload.sql:166](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/city/build_city_page_payload.sql:166).

`ARRAY_AGG(price_amount ORDER BY (... ARRAY_AGG(price_currency ...) ...))` chứa aggregate trong aggregate cùng cấp. Đã lấy nguyên biểu thức mới, chạy SELECT read-only trên PostgreSQL 17 với hai dòng `100 USD`, `80 GBP`: nhận **`aggregate function calls cannot be nested`**. Đây là lỗi SQL thực tế, không phải nhận xét style.

Khi publication gọi builder cho một city page, SQL này thất bại; candidate không được kích hoạt. Test Deno không chạy nội dung SQL nên vẫn pass. Cần chọn currency ở CTE/subquery riêng rồi aggregate nhóm đã chọn. Không so sánh số tiền khác currency để chọn giá rẻ nhất nếu chưa quy đổi.

### R2. [P1] Migration sạch vẫn REVOKE/GRANT chữ ký publication không tồn tại

Vị trí: [publish_read_model_version.sql:188](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/shared/publish_read_model_version.sql:188), [migration:952](/Users/winn/Documents/Tripways/tripways-backend/supabase/migrations/20260714080900_pseo_functions.sql:952).

Source tạo hàm `(TEXT, BOOLEAN DEFAULT FALSE)` nhưng cuối file vẫn `REVOKE/GRANT ... publish_read_model_version(TEXT)`. Tìm toàn bộ migrations chỉ thấy định nghĩa 2 tham số mới; không có định nghĩa 1 tham số. Default argument cho phép gọi thiếu argument nhưng không tạo thêm chữ ký function để cấp quyền. Vì vậy cài foundation trên DB sạch sẽ vấp chữ ký không tồn tại.

Đây là kết luận từ toàn bộ migration, chưa chạy reset trên DB dùng chung. Nếu áp dụng bằng CREATE OR REPLACE vào DB cũ thì thêm overload 2 tham số, không thay thế overload 1 tham số; cần xử lý tương thích có chủ đích, tránh giữ code cũ cho lời gọi 1 tham số. Không dùng sự tồn tại overload cũ trên máy dev để kết luận migration sạch hợp lệ.

### R3. [P1] Token lease được kiểm tra sau thao tác ghi, không chặn stale worker

Vị trí: [publish prices:127](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:127), [lease update:180](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:180), [airport finalize:51](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_finalize_airport_route_refresh_lease.sql:51).

Acquire hiện dùng token mới để xác định người thắng, đã sửa lỗi nhiều request cùng nhận lease. Nhưng price publisher UPSERT toàn bộ giá trước khi so token ở UPDATE lease. Worker A hết lease, worker B acquire/publish, rồi A trả muộn: A vẫn ghi đè giá của B. Airport handler cũng ingest routes trước khi finalize token, nên tương tự.

Điều kiện `p_lease_token IS NULL OR lease_token IS NULL OR lease_token=p_lease_token` còn cho phép token thiếu hoặc token cũ khi row đã được finalize về NULL. UPDATE không match cũng không báo lease lost; RPC vẫn trả fresh/success.

Cần khóa/kiểm tra owner và thời hạn **trước mọi mutation**, bắt buộc token cho flow cache, và giữ kiểm tra+ghi+finalize trong cùng transaction. Worker mất lease phải nhận trạng thái rõ ràng và không ghi dữ liệu. Chưa chạy thử concurrency mutation trên DB dùng chung; kết luận dựa vào thứ tự và predicate của source.

### R4. [P1] Hai cron Travelpayouts vẫn bị từ chối; mode chưa có nghiệp vụ

Vị trí: [cron:81](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/operations/configure_ingestion_crons.sql:81), [cron:96](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/operations/configure_ingestion_crons.sql:96), [request parser:49](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/flight/route-cache/request.ts:49).

URL slug và config đã được sửa. Parser đã cho phép key `mode` nhưng vẫn yêu cầu `origin`. Hai payload cron chỉ có mode, nên chạy parser mới vẫn nhận `ERR_FLIGHT_ROUTE_CACHE_INVALID_REQUEST` cho cả warm_top_routes và day6_active_refresh.

Thêm origin cũng chỉ refresh origin đó: handler không có nhánh xử lý mode, không chọn top routes hay active demand. Cần triển khai batch orchestration có giới hạn/quyền worker hoặc bỏ schedule chưa hỗ trợ. Day-6 refresh còn cần chính sách vượt qua cache-hit fresh một cách có kiểm soát; hiện acquire thấy giá chưa hết hạn sẽ không gọi provider.

### R5. [P1] Ingestion vẫn chưa cập nhật publication; dữ liệu snapshot vẫn có thể hết hạn

Vị trí: [price publisher](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:168), [route ingestion service](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/service.ts:67), [page reader](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/shared/rpc_get_page.sql:69).

Không có bước nối ingest/cache→publish read models trong flow và cron mới. Cache thành công chưa làm page/search đổi version. Bộ lọc freshness của route/price vẫn ở thời điểm dựng projection; reader đọc snapshot không kiểm tra lại expiry. Giá trong search projection không lưu expiry để enforce.

Cần hoàn thiện publication/invalidation và expiry độc lập với provider success. `p_allow_empty` là bổ sung hữu ích, nhưng chưa có orchestration sử dụng nó để gỡ dữ liệu đã hết hạn. Đây là finding cũ 07 còn nguyên.

### R6. [P2] Cold price response vẫn sai contract và có thể báo fresh dù không publish được giá nào

Vị trí: [handler:139](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/flight/route-cache/handler.ts:139), [publisher:182](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:182).

Cold response trả nguyên observation adapter camelCase không có `observation_ref`; warm response trả DTO SQL snake_case có ref. Count vẫn theo input length. SQL skip airport chưa map/cặp city không hợp lệ nhưng vẫn kết thúc status fresh, kể cả inserted_count=0.

Đã gọi handler hiện tại với **dependency mock**: provider trả 1 observation, publish trả `published_count=0`; kết quả HTTP 200, fresh, count 1, thiếu observation_ref. Đây là test runtime của handler, không phải bằng chứng provider hoặc DB publish đã chạy.

Sửa cold/warm dùng một DTO từ dữ liệu canonical đã persist; báo số accepted/skipped thực tế và trạng thái empty khi không có giá dùng được. Airport handler cũng vẫn báo routes_count theo input length, finalize error chỉ log rồi trả thành công.

### R7. [P2] Timeout AeroDataBox chỉ bao phủ headers, không bao phủ response body

Vị trí: [aerodatabox-provider.ts:235](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/providers/aerodatabox-provider.ts:235), [body read:247](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/providers/aerodatabox-provider.ts:247).

Timer bị clear ngay sau `await fetch`, trước `response.text/json`. Nếu provider trả headers ngay rồi body treo, timeout 10 giây không còn tác dụng.

Đã chạy adapter thật với fetch dependency trả Response stream chậm 10.200 ms: hoàn thành sau **10.205 ms**, `signalAborted=false`. Đây là kiểm chứng có stream giả lập, không gọi provider ngoài. Cần để timer tồn tại đến khi đọc/parse body xong, đồng thời giới hạn kích thước body và ngân sách toàn batch.

### R8. [P2] Approval mới chưa được enforce cho mọi nguồn/giá/môi trường

Vị trí: [production route gate:97](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql:97), [price selection:74](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql:74), [price source:42](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:42).

Route projection đã kiểm tra is_fixture/is_approved cho production. Nhưng `environment` không được dùng; giá được attach vào projection/page/handoff không join source approval. Price publisher vẫn chấp nhận source Travelpayouts tồn tại dù is_approved=false, thậm chí tự approve nếu chưa có source. Bản seed Travelpayouts chỉ set id/code/name nên mặc định không approved, nhưng publisher không từ chối.

Cần một quyết định approval rõ ràng và kiểm tra ở boundary publish/read tương ứng. Trước: chỉ gate nguồn route; sau: gate cả nguồn route và nguồn price, khớp môi trường. Fixture flags trong seed cũng phải tường minh để không dựa vào approval mặc định vô tình chặn fixture.

### R9. [P2] Unknown schedule và giá theo itinerary vẫn chưa được giải quyết đầy đủ

Vị trí: [parseDaysOfWeek](/Users/winn/Documents/Tripways/tripways-backend/supabase/functions/v1/ingestion/routes/providers/aerodatabox-provider.ts:53), [price normalization](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/ingestion/rpc_publish_price_observations.sql:84), [projection](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/route_discovery/refresh_route_search_options.sql:74).

Giao lịch rỗng đã sửa và connecting projection đã loại giao rỗng. Tuy nhiên missing days vẫn là cả tuần; duration ước lượng chưa được phân biệt với duration provider; direct unknown vẫn thành true. Chưa có giờ bay để kiểm chứng nối chuyến qua ngày/múi giờ.

Price identity đã bổ sung market/airline/return-date/direct và UPDATE metadata, nhưng các offer cùng chiều này vẫn có thể trùng (ví dụ 1 stop và 2 stops cùng là con). Projection vẫn chọn giá không theo market/currency và one-stop không match hub/airline cụ thể. Cần trả giá tham khảo theo scope đúng hoặc match itinerary đầy đủ, không gán độ chính xác cao hơn dữ liệu có.

### R10. [P2] Cleanup publication mới xóa cả dữ liệu của bản rollback gần nhất

Vị trí: [publish_read_model_version.sql:140](/Users/winn/Documents/Tripways/tripways-backend/supabase/sql_src/functions/pseo/shared/publish_read_model_version.sql:140).

Sau khi publish, code xóa flight_route_options và mọi page read model của **tất cả** version retired. Dù giữ row publication trong 7 ngày, payload của bản trước đã mất. Nếu cần chuyển lại version trước khi phát hiện data quality issue, không còn snapshot để phục hồi bằng cách đổi current marker; phải rebuild.

So với bản trước có giữ immediate rollback candidate, đây là thay đổi làm mất khả năng phục hồi. Giữ ít nhất một bản hoàn chỉnh, hoặc ghi rõ rollback chỉ thực hiện bằng rebuild và xác minh quy trình đó. Chưa thực hiện thao tác publish/delete trên DB trong review.

## Trạng thái 21 mục của báo cáo trước

“Đã sửa source” nghĩa là đã đối chiếu code/migration; chưa đồng nghĩa đã migration và pass SQL integration trên DB mới.

| Mục cũ                           | Trạng thái sau recheck                                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 01 — private schema transport    | Đã sửa source: public invoker wrappers, service_role only, handler dùng public RPC                                  |
| 02 — cột nguồn không tồn tại     | Đã sửa source: lookup code; vẫn còn approval R8                                                                     |
| 03 — autocomplete envelope       | Đã sửa source và config; DB local vẫn bản cũ                                                                        |
| 04 — cấp lease trùng             | Acquire đã sửa; write/finalize fencing còn lỗi R3                                                                   |
| 05 — lease NULL kẹt mãi          | Đã sửa transition trong source; cần test SQL concurrency/expiry                                                     |
| 06 — NULL uniqueness             | Đã sửa source thành UNIQUE NULLS NOT DISTINCT                                                                       |
| 07 — publication/expiry          | Chưa sửa, R5                                                                                                        |
| 08 — mất city mapping            | Đã sửa COALESCE giữ city_id cũ khi incoming NULL                                                                    |
| 09 — source trust                | Một phần: gate route; environment/price chưa đầy đủ, R8                                                             |
| 10 — lịch và unknown             | Một phần: giao rỗng đã sửa; unknown/ước lượng còn, R9                                                               |
| 11 — giá nhiều chiều             | Một phần: key/metadata cải thiện; city SQL mới bị R1; itinerary còn R9                                              |
| 12 — cron                        | URL/config/secret/all_eligible đã sửa; cron giá vẫn lỗi R4                                                          |
| 13 — đếm direct/publication rỗng | Đã sửa đếm tổng, thêm allow_empty; có regression R2 và R10                                                          |
| 14 — duplicate envelope          | Đã sửa counts/guard; checksum bỏ qua filter version vẫn còn                                                         |
| 15 — provider/finalize errors    | Provider error đã trả 503, truncate failure code; finalize success path vẫn chỉ log lỗi, R6                         |
| 16 — cold/warm/timestamps        | observedAt và airport matching đã sửa; DTO/count chưa, R6                                                           |
| 17 — payload/cache               | routes city/airport đã limit; featured_destinations vẫn unbounded, POST/CDN chưa kiểm chứng                         |
| 18 — quota/timeout               | Có timeout headers nhưng body chưa, R7; shared quota/checkpoint chưa có                                             |
| 19 — typecheck/staging signature | Đã sửa; edge:check gồm đủ 10 entrypoints và pass; staging signature TEXT                                            |
| 20 — content tooling             | Có --environment, giữ editorial khi regenerate; vẫn default fixture, tự reviewed, ghi seed lẫn migration, log dbUrl |
| 21 — city rename                 | Đã sửa update-first theo source identity; slug Unicode/collision chưa được chứng minh                               |

## Verification mới

- Test Deno: **162 passed, 0 failed**.
- `pnpm edge:check`: **pass**, bao gồm route-cache và ingestion routes.
- `pnpm format:check`: **pass** trước khi thêm tài liệu recheck.
- `pnpm edge:fmt:check`: **pass**, 85 files.
- So sánh **57/57 SQL source** với các generated sections: không drift. Điều này không kiểm chứng SQL thực thi hợp lệ.
- PostgreSQL read-only tái hiện R1 bằng SELECT nguyên biểu thức mới.
- Parser mới tái hiện R4 với cả hai payload cron.
- Handler dependency test tái hiện R6: HTTP 200, fresh, count 1, published_count 0, không observation_ref.
- Adapter Response-stream test tái hiện R7: 10.205 ms, AbortSignal chưa abort.
- DB local chưa có schema/function fixes mới; chưa chạy full SQL integration hay benchmark/concurrency trên bản sửa.
- Đầu lần kiểm tra có staged changes rồi repo chuyển thành commit 025ff51 trong lúc đọc; baseline đã được kiểm tra lại ổn định. Agent không thực hiện Git mutation.

## Thứ tự xử lý

1. R1, R2: sửa SQL blocker và kiểm chứng foundation trên DB test sạch.
2. R3, R4, R5: hoàn thiện cache owner, job orchestration và publication/expiry.
3. R6–R10: DTO, failure semantics, timeout, trust, data semantics và rollback.
4. Chạy test SQL thực với acquire đồng thời, stale worker, NULL scope, fresh→expired, empty→retry, publish chỉ direct, empty publication, source revoked và cold/warm response thống nhất.

implemented: kiểm tra lại bản sửa và cập nhật báo cáo; skipped: sửa implementation, Git mutation, reset/migrate DB, provider live; add when: có đợt sửa tiếp và môi trường SQL test cô lập để chạy integration/concurrency đầy đủ.
