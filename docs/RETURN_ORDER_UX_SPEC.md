# Đặc tả UX Hoàn đơn — Customer, Driver, CSKH

> Trạng thái: thiết kế sẵn sàng triển khai, chưa thay đổi schema/RLS/RPC hoặc Supabase remote.
> Phạm vi: hoàn hàng sau khi tài xế đã nhận kiện; điều hướng về điểm trả; phí hoàn; trải nghiệm nhất quán giữa Customer, Driver và Support.
> Design direction: `Clean Utility Premium`, dùng `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius` trong `giaohang_design`.

## 1. Kết quả cần đạt

Người dùng phải hiểu trạng thái hoàn đơn trong một giây:

- Customer biết vì sao đơn đang hoàn, tài xế đang ở đâu, dự kiến khi nào hoàn xong và mình phải trả/được hoàn bao nhiêu.
- Driver nhận một chặng điều hướng rõ ràng từ vị trí hiện tại về điểm trả, có thu nhập dự kiến và chỉ xác nhận sau khi đã đến nơi.
- CSKH có đủ dữ liệu để quyết định nơi trả, bên chịu phí và mức phí trước khi phát lệnh.
- Một quyết định chỉ tạo một hành trình hoàn; thao tác lặp do mạng chậm không được thu phí hoặc chuyển trạng thái hai lần.

Không dùng `cancelled` để thay cho “đã hoàn”. `cancelled` là đơn dừng trước khi hoàn tất trách nhiệm hàng hóa; `returned` là kiện đã được bàn giao lại thành công.

## 2. Lifecycle chuẩn

```text
delivering
   │ Driver báo sự cố, hoặc Customer gửi yêu cầu hỗ trợ để CSKH tiếp nhận
   ▼
waiting_support
   │ CSKH duyệt nơi trả + bên chịu phí + quote
   ▼
return_approved
   │ Driver bấm “Bắt đầu quay về”
   ▼
returning
   │ GPS vào vùng 100 m + có bằng chứng bàn giao
   ▼
returned
```

Nhánh xử lý:

- `waiting_support → delivering`: CSKH cho tiếp tục giao.
- `waiting_support → return_approved`: CSKH phê duyệt hoàn.
- `return_approved → returning`: chỉ assigned Driver được bắt đầu.
- `returning → returned`: chỉ assigned Driver xác nhận; RPC kiểm tra transition và ghi event atomically.
- Không tự động chuyển trạng thái khi countdown hết hạn.
- Sau `returned`, incident chuyển `resolved`, tài xế được giải phóng và tài chính được chốt cùng transaction.
- Customer không tự chuyển trạng thái hoàn; yêu cầu từ Customer chỉ tạo ticket/case để CSKH xác minh.

## 3. Mô hình thông tin dùng chung

Ba role cùng nhìn một nguồn dữ liệu nhưng khác độ chi tiết:

| Dữ liệu | Customer | Driver | CSKH |
|---|---:|---:|---:|
| Trạng thái hoàn | Có | Có | Có |
| Điểm trả + ETA | Có | Có | Có |
| Phí khách chịu | Có | Có | Có |
| Thu nhập tài xế | Không | Có | Có |
| Lý do công khai | Có | Có | Có |
| Ghi chú nội bộ | Không | Không | Có |
| Evidence | Chỉ biên nhận hoàn tất | Tạo/xem của mình | Xem toàn bộ |
| Vị trí live | Khi `returning` | Có | Có |

Các nhãn trạng thái chuẩn:

| State | Nhãn Customer | Nhãn Driver | Nhãn CSKH |
|---|---|---|---|
| `waiting_support` | CSKH đang xử lý | Chờ hướng dẫn từ CSKH | Chờ quyết định |
| `return_approved` | Đã duyệt hoàn hàng | Sẵn sàng quay về | Đã phát lệnh hoàn |
| `returning` | Tài xế đang hoàn hàng | Đang quay về điểm trả | Đang hoàn hàng |
| `returned` | Đã hoàn hàng | Hoàn hàng thành công | Đã hoàn tất |

## 4. Customer UX

### 4.1. Tracking — banner trạng thái

Banner nằm trên bottom sheet tracking, không che bản đồ. Toàn bộ banner tappable để mở chi tiết; chỉ có một CTA phụ khi thật sự cần liên hệ.

```text
┌────────────────────────────────────┐
│ ↩  Tài xế đang hoàn hàng           │
│    Về điểm lấy ban đầu             │
│    3,2 km  •  khoảng 12 phút       │
│                                    │
│ Phí bạn thanh toán       26.000 đ  │
│                         Xem chi tiết ›│
└────────────────────────────────────┘
```

Quy tắc hiển thị:

- `return_approved`: map vẫn giữ vị trí tài xế, banner ghi “Tài xế chuẩn bị quay về”.
- `returning`: route đổi thành Driver → điểm trả; marker điểm trả dùng `markerPickup` kèm icon return, không chỉ đổi màu.
- `returned`: banner success gọn, có giờ hoàn tất và nút “Xem biên nhận”.
- Nếu quote chưa chốt, hiển thị “Chi phí đang được CSKH xác nhận”, tuyệt đối không hiển thị số tạm tính như số đã thu.

### 4.2. Chi tiết hoàn đơn

Bottom sheet gồm đúng bốn khối theo thứ tự:

1. Timeline bốn mốc: duyệt hoàn → bắt đầu quay về → đến điểm trả → hoàn tất.
2. Điểm trả: tên người/đơn vị nhận, địa chỉ, ETA.
3. Tài chính: phí giao ban đầu, phí chặng hoàn, giảm/hoàn tiền, tổng khách phải trả.
4. Trợ giúp: “Liên hệ CSKH”; không lộ ghi chú nội bộ, số riêng của tài xế hoặc evidence điều tra.

Copy tránh đổ lỗi. Hiển thị “Lý do hoàn: Không liên lạc được người nhận”, không dùng câu “Bạn đã không…”.

### 4.3. Lịch sử đơn
- Badge `Đã hoàn` khác badge `Đã hủy`.
- Card giữ route lấy → giao nhưng thêm return rail giao → trả.
- Giá trên card là số cuối cùng Customer đã trả; breakdown mở bằng tap.

## 5. Driver UX

### 5.1. Trạng thái `return_approved`

Không cho bấm ngay “Đã hoàn tất”. Thay bằng return mission card:

```text
┌────────────────────────────────────┐
│ ↩  HOÀN HÀNG                       │
│ Quay về điểm lấy                   │
│ 128 Trần Văn Ơn, Thủ Đức           │
│                                    │
│ 3,2 km     12 phút      +26.000 đ  │
│                                    │
│ [       Bắt đầu quay về       ]    │
│  Gọi người gửi       Liên hệ CSKH  │
└────────────────────────────────────┘
```

- Primary CTA duy nhất: `Bắt đầu quay về`.
- `+26.000 đ` là thu nhập chặng hoàn đã duyệt, không phải phí Customer nếu bên trả là platform.
- Tên người chịu phí không cần xuất hiện trên màn Driver.
- Hướng dẫn CSKH nằm trong section thu gọn “Lưu ý bàn giao”.

### 5.2. Trạng thái `returning`

Màn navigation tái sử dụng map hiện có nhưng đổi context chặng:

- Target = tọa độ return destination, mặc định pickup gốc.
- OSRM route = vị trí Driver hiện tại → return destination.
- Top maneuver card ghi “Đang quay về điểm trả”.
- Progress có ba bước `Quay về → Đến nơi → Bàn giao`, không tái sử dụng progress giao hàng bốn bước.
- Bottom panel hiển thị địa chỉ, người nhận lại hàng, ETA, khoảng cách, nút gọi và CTA bị khóa cho đến khi vào geofence.
- Route refresh tiếp tục mỗi 20 giây; GPS/realtime tiếp tục gửi mỗi 5 giây theo policy hiện có.

Trạng thái lỗi:

- OSRM lỗi: giữ route cũ; nếu chưa có route thì vẽ fallback line và ghi “Đường đi chỉ mang tính định hướng”.
- Mất mạng: vẫn điều hướng với route cuối; CTA hoàn tất được xếp hàng chờ đồng bộ, nhưng UI chưa công bố “Đã hoàn” cho tới khi server xác nhận.
- GPS yếu: cho mở hướng dẫn và gọi hỗ trợ; không cho bypass geofence bằng tap đơn. CSKH có override riêng kèm lý do audit.

### 5.3. Xác nhận hoàn hàng

Khi vào phạm vi 100 m, CTA đổi thành `Xác nhận đã bàn giao`. Bottom sheet xác nhận gồm:

- Ảnh kiện tại điểm trả: bắt buộc.
- Tên người nhận lại hàng: bắt buộc, 2–80 ký tự.
- Ghi chú: tùy chọn.
- Checkbox “Tôi đã bàn giao kiện cho đúng người/đơn vị”.
- CTA `Hoàn tất đơn` disabled cho đến khi dữ liệu hợp lệ.

Sau RPC thành công hiển thị success receipt:

- mã đơn;
- thời gian hoàn tất;
- thu nhập chặng hoàn;
- trạng thái đối soát;
- CTA `Về danh sách đơn`.

## 6. CSKH UX

### 6.1. Workspace

Desktop dùng bố cục responsive master-detail, không mở nhiều dialog chồng nhau:

```text
┌──────── Queue 320 ───────┬──────── Case detail ────────┬── Decision 360 ──┐
│ Filter + search          │ Order + route map            │ Current state     │
│ Incident cards           │ Customer / Driver / Recipient│ Return quote      │
│ SLA / waiting badge      │ Evidence + conversation      │ Primary action    │
└──────────────────────────┴───────────────────────────────┴──────────────────┘
```

- Từ 1280 px: ba cột.
- 768–1279 px: queue + detail, decision mở side sheet.
- Dưới 768 px: list → detail → action theo navigation stack.
- Queue ưu tiên `waiting_support`, sau đó theo SLA; màu không phải tín hiệu duy nhất.

### 6.2. Dialog “Duyệt hoàn hàng”

Đây là một flow ba bước ngắn, có thể quay lại:

1. **Nơi trả**
   - `Điểm lấy ban đầu` mặc định.
   - `Trung tâm xử lý` khi hàng nguy hiểm/tranh chấp.
   - Địa chỉ và tọa độ phải được xác nhận trên mini map.
2. **Chi phí**
   - Lý do chuẩn hóa.
   - Bên chịu phí: Customer / Platform.
   - Quote từ OSRM + pricing policy, có distance, duration và breakdown.
   - Cho override số tiền chỉ với quyền phù hợp và lý do bắt buộc.
3. **Xác nhận**
   - Tóm tắt điểm trả, bên chịu phí, số khách phải trả, thu nhập Driver.
   - CTA `Phát lệnh hoàn`.

Sau khi phát lệnh, decision rail biến thành live mission card: trạng thái, vị trí, ETA, last GPS update, nút gọi Driver và action override. Không để action “Xác nhận đã giải quyết hàng hóa” cạnh tranh với Driver; CSKH chỉ override khi có lý do và event audit.

## 7. Chính sách chi phí đề xuất

Phân biệt hai con số:

- `customer_return_charge`: Customer bị thu thêm bao nhiêu.
- `driver_return_earning`: Driver được ghi nhận bao nhiêu cho chặng quay về.

Không suy ra một số từ số còn lại ở client; server chốt cả hai trong cùng quote.

### 7.1. Quote chặng hoàn
Đề xuất tái sử dụng `DeliveryPricingPolicy` theo quãng đường OSRM từ vị trí Driver lúc CSKH duyệt tới return destination:

```text
standard_return_quote = DeliveryPricingPolicy.calculate(return_distance)
driver_return_earning = standard_return_quote.total
```

Không cộng COD hàng hóa vào phí hoàn. COD chưa thu ở người nhận phải về `0`; tiền hàng/tiền ứng được xử lý bởi ledger tài chính riêng.

### 7.2. Bên chịu phí

| Nhóm nguyên nhân | Customer charge | Driver earning | Mặc định |
|---|---:|---:|---|
| Người nhận vắng mặt / từ chối / sai thông tin do người gửi | 100% quote | 100% quote | Customer |
| Lỗi Driver được xác minh | 0 | Theo quyết định CSKH | Platform |
| Lỗi hệ thống / điều phối | 0 | 100% quote | Platform |
| Hàng cấm / mất an toàn / tranh chấp | Chưa thu đến khi review | 100% quote | Pending Support |

Mọi override cần `reason`, actor và timestamp. UI phải nói rõ “Ai trả” và “Driver nhận” thay vì một nhãn mơ hồ “Phí hoàn”.

### 7.3. Breakdown Customer

```text
Phí giao ban đầu              32.000 đ
Phí hoàn về điểm lấy          26.000 đ
Hỗ trợ từ GiaoHang           -10.000 đ
────────────────────────────────────
Tổng thanh toán               48.000 đ
```

- Nếu chưa thu: dùng `Sẽ thanh toán`.
- Nếu đã thu: dùng `Đã thanh toán` và dòng `Hoàn lại` riêng.
- Không dùng số âm không có nhãn.

## 8. Data contract đề xuất — cần phê duyệt riêng trước khi triển khai

Backend hiện tại dùng `RiskInterventionState.returnRequired`, sau đó `confirm_risk_custody_resolved` chuyển order thành `cancelled` và intervention thành `released`. Contract này không đủ cho navigation, live tracking và đối soát phí hoàn.

Giữ hướng đã có trong `ORDER_INCIDENT_MVP_ROADMAP.md`:

- Order statuses: `waiting_support`, `return_approved`, `returning`, `returned`.
- Bảng `order_returns`, một row duy nhất cho mỗi order.
- RPC: `support_approve_return`, `start_order_return`, `confirm_order_return`.

Các field cần thêm vào contract `order_returns` để đáp ứng UX chi phí/điều hướng:

```text
destination_type             sender | processing_center
destination_address
destination_lat
destination_lng
route_origin_lat             vị trí Driver lúc quote
route_origin_lng
route_distance_m
route_duration_s
quote_source                 osrm | fallback
reason_code
fee_payer                    customer | platform | pending_support
customer_return_charge
driver_return_earning
fee_status                   quoted | approved | settled | waived
fee_override_reason
receiver_name
proof_storage_path
approved_at
started_at
arrived_at
returned_at
```

Các RPC phải idempotent, khóa row theo thứ tự order → incident → return, xác thực role từ `public.users`, ghi finance ledger/event atomically, revoke execute khỏi `PUBLIC` rồi grant có chủ đích.

Realtime subscription chỉ đọc row mà role được phép xem. Customer không được select internal note, evidence điều tra hoặc `fee_override_reason`.

## 9. Notification matrix

| Event | Customer | Driver | CSKH |
|---|---|---|---|
| Return approved | Push + in-app | Push + mission card | Timeline event |
| Driver started return | In-app + map | Navigation mode | Live mission |
| Driver arrived | In-app | Haptic + proof sheet | Timeline event |
| Return completed | Push + receipt | Success receipt | Queue resolved |
| Quote changed before approval | Không gửi | Không gửi | Inline warning |
| Fee settled/refunded | Push + finance receipt | Wallet/earning update | Finance event |

## 10. Accessibility và interaction quality

- Touch target mobile tối thiểu 48×48 dp; web có focus ring và keyboard navigation.
- Không dùng màu làm tín hiệu duy nhất: mọi status có icon + text.
- Tất cả icon-only action có tooltip và semantic label.
- Support Dynamic Type/text scaling; card tài chính wrap, không ép một hàng.
- Loading action disabled và giữ nguyên kích thước; transition 150–300 ms.
- Không dùng dialog lồng dialog; flow CSKH dùng stepper/side sheet duy nhất.
- CTA sticky phải nằm trên safe area; scroll content có bottom inset tương ứng.
- Map là ngữ cảnh, không phải nơi duy nhất chứa địa chỉ/ETA.

## 11. Kế hoạch component/file — tránh God file

`driver_navigation_screen.dart` hiện khoảng 779 dòng, nên không thêm return logic trực tiếp trước khi tách. Split plan:

```text
features/driver/screens/navigation/
├── driver_navigation_screen.dart          # Scaffold + provider wiring
├── controllers/
│   ├── driver_navigation_controller.dart  # GPS, route refresh, camera
│   └── driver_return_controller.dart      # return state/RPC/proof
├── models/
│   ├── driver_navigation_target.dart
│   └── driver_return_workflow.dart
├── widgets/
│   ├── driver_return_mission_panel.dart
│   ├── driver_return_progress.dart
│   ├── driver_return_confirmation_sheet.dart
│   └── driver_return_success_sheet.dart
└── utils/
    └── driver_return_route_policy.dart
```

Customer:

```text
features/returns/
├── models/order_return_view.dart
├── data/order_return_repository.dart
├── widgets/customer_return_status_banner.dart
├── widgets/customer_return_finance_breakdown.dart
└── sheets/customer_return_details_sheet.dart
```

Tích hợp vào tracking qua widget/helper hiện có; không nhồi logic vào `tracking_screen.dart`.

Operations Web:

```text
features/returns/
├── models/support_return_case.dart
├── data/support_return_repository.dart
├── widgets/support_return_decision_rail.dart
├── widgets/support_return_live_mission.dart
└── dialogs/approve_return_flow.dart
```

## 12. Acceptance criteria

### Customer

- Nhìn đúng nhãn `Đã hoàn`, không bị gom vào `Đã hủy`.
- Khi Driver `returning`, map và ETA cập nhật live về đúng return destination.
- Breakdown phân biệt tiền đã thu, sẽ thu và được hoàn.
- Không thấy internal note/evidence điều tra.

### Driver

- `return_approved` chưa thể xác nhận hoàn ngay.
- `Bắt đầu quay về` chuyển sang `returning` đúng một lần.
- Route OSRM đi từ vị trí hiện tại về return destination.
- CTA hoàn tất chỉ bật trong geofence và khi proof hợp lệ.
- Sau success, active session được đóng và earning được hiển thị.

### CSKH

- Không thể phát lệnh nếu thiếu destination, payer hoặc quote.
- Preview hiển thị riêng Customer charge và Driver earning.
- Action đang chạy bị disabled; retry không tạo return/charge trùng.
- Mọi override phí hoặc geofence có lý do và audit event.

### Verification tập trung

- Unit test: state policy, target selection, fee/payer policy, money formatting.
- Widget test Delivery App: return mission, geofence disabled, proof validation, Customer banner/breakdown, text scale.
- Widget test Operations Web: three-step approval, invalid quote, disabled submit, responsive layout, keyboard focus.
- SQL test: transitions, authorization/RLS, idempotency, finance atomicity.
- Không apply migration lên remote trước khi local SQL tests và hai app tests đều pass, sau đó phải xin xác nhận riêng.

## 13. Thứ tự triển khai đề xuất

1. Chốt policy phí và quyền override.
2. Phê duyệt schema/RLS/RPC riêng.
3. Tách `driver_navigation_screen.dart` theo split plan.
4. Triển khai shared domain + SQL contract/tests.
5. Triển khai Driver return navigation.
6. Triển khai Customer status/finance view.
7. Triển khai CSKH approval/live mission.
8. Chạy verification tập trung, sau đó mới xem xét remote apply.
