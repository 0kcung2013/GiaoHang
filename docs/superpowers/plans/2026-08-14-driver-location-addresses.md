# Driver Location Addresses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiển thị địa chỉ cụ thể thay cho tọa độ trong ba thẻ đối chiếu vị trí của tài xế.

**Architecture:** Chuyển reverse-geocoding hiện có sang `core` để Customer và Driver dùng chung. Driver sheet tra cứu tuần tự các tọa độ duy nhất, cache kết quả theo tọa độ và chỉ đưa chuỗi địa chỉ/loading/fallback vào component hiển thị.

**Tech Stack:** Flutter 3.35.1, Dart 3.9, `http`, `latlong2`, Nominatim/OpenStreetMap, Flutter test.

## Global Constraints

- Không thay đổi Supabase schema, RLS, migrations, Edge Functions hoặc database fields.
- Không thêm dependency và không gọi Nominatim thật trong test.
- UI dùng `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius` từ `giaohang_design`.
- Không hiển thị tọa độ số trong UI hoặc fallback.
- Chỉ chạy test/analyze tập trung.

---

### Task 1: Chuyển reverse geocoding dùng chung vào core

**Files:**
- Create: `apps/delivery_app/lib/core/models/reverse_geocode_result.dart`
- Create: `apps/delivery_app/lib/core/services/reverse_geocoding_service.dart`
- Delete: `apps/delivery_app/lib/features/customer/screens/create_order/utils/reverse_geocode_result.dart`
- Delete: `apps/delivery_app/lib/features/customer/screens/create_order/utils/reverse_geocoding_service.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/create_order/controllers/address_picker_controller.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/create_order/widgets/address_picker/address_detail_form.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/create_order/utils/address_search_result.dart`
- Test: `apps/delivery_app/test/reverse_geocode_result_test.dart`

**Interfaces:**
- Produces: `ReverseGeocodeResult`, `ReverseGeocodingService.resolve(LatLng)`, `ReverseGeocodingService.dispose()` giữ nguyên hành vi hiện tại.
- Consumes: `http.Client`, `LatLng`, phản hồi JSON Nominatim.

- [ ] **Step 1: Đổi test sang import core để tạo RED**

```dart
import 'package:delivery_app/core/models/reverse_geocode_result.dart';
```

- [ ] **Step 2: Chạy test và xác nhận thất bại đúng lý do**

Run: `flutter test test/reverse_geocode_result_test.dart`
Expected: FAIL vì `core/models/reverse_geocode_result.dart` chưa tồn tại.

- [ ] **Step 3: Di chuyển model/service và cập nhật toàn bộ import Customer**

Giữ nguyên parsing, timeout 8 giây, `User-Agent`, `accept-language=vi` và exception hiện có. Service core import model bằng:

```dart
import '../models/reverse_geocode_result.dart';
```

- [ ] **Step 4: Chạy test và xác nhận PASS**

Run: `flutter test test/reverse_geocode_result_test.dart`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit riêng phần core**

```bash
git add apps/delivery_app/lib/core/models/reverse_geocode_result.dart apps/delivery_app/lib/core/services/reverse_geocoding_service.dart apps/delivery_app/lib/features/customer/screens/create_order apps/delivery_app/test/reverse_geocode_result_test.dart
git commit -m "refactor: share reverse geocoding service"
```

### Task 2: Hiển thị địa chỉ trong thẻ kiểm tra vị trí tài xế

**Files:**
- Create: `apps/delivery_app/test/driver_gps_debug_components_test.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_components.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart`

**Interfaces:**
- Consumes: `ReverseGeocodingService.resolve(LatLng)` từ Task 1.
- Produces: `DriverGpsCoordinateCard(address: String)` và `DriverGpsStoredCard(address: String)`; sheet quản lý cache `Map<String, String>`.

- [ ] **Step 1: Viết widget test tạo RED**

Test render card với địa chỉ, loading và fallback; luôn xác nhận `find.textContaining('10.779000')` và `find.textContaining('106.676500')` trả về `findsNothing`.

```dart
DriverGpsCoordinateCard(
  icon: Icons.my_location_rounded,
  color: AppColors.info,
  title: 'GPS thiết bị',
  subtitle: 'Vị trí thật do thiết bị cung cấp',
  address: '12 Nguyễn Huệ, Bến Nghé, Quận 1, TP.HCM',
)
```

- [ ] **Step 2: Chạy test và xác nhận thất bại đúng lý do**

Run: `flutter test test/driver_gps_debug_components_test.dart`
Expected: FAIL vì component chưa có tham số `address` và vẫn nhận `position`.

- [ ] **Step 3: Đổi component từ tọa độ sang địa chỉ**

`DriverGpsCoordinateCard` nhận chuỗi `address`, render bằng `AppTextStyles.bodySmall`, tối đa ba dòng; bỏ `LatLng`, `SelectableText` và mono coordinate. `DriverGpsStoredCard` truyền tiếp `address`.

- [ ] **Step 4: Tích hợp tra cứu/cache vào sheet**

Khởi tạo và dispose `ReverseGeocodingService`. Dùng khóa `${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}`; resolve tuần tự từng tọa độ duy nhất. Trong khi chờ trả `Đang xác định địa chỉ…`; null/lỗi/rỗng trả `Không xác định được địa chỉ`. Sau `_loadPosition` và `_applyLocationMode`, tra cứu các điểm mới bằng `unawaited` và chỉ `setState` khi mounted. Đổi heading thành `Đối chiếu vị trí`.

- [ ] **Step 5: Chạy test component và reverse-geocode**

Run: `flutter test test/driver_gps_debug_components_test.dart test/reverse_geocode_result_test.dart`
Expected: tất cả PASS, không có network call thật.

- [ ] **Step 6: Format và analyze tập trung một lượt**

Run: `dart format lib/core/models/reverse_geocode_result.dart lib/core/services/reverse_geocoding_service.dart lib/features/customer/screens/create_order/controllers/address_picker_controller.dart lib/features/customer/screens/create_order/widgets/address_picker/address_detail_form.dart lib/features/customer/screens/create_order/utils/address_search_result.dart lib/features/driver/screens/widgets/driver_gps_debug_components.dart lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart test/reverse_geocode_result_test.dart test/driver_gps_debug_components_test.dart`

Run: `flutter analyze lib/core/models/reverse_geocode_result.dart lib/core/services/reverse_geocoding_service.dart lib/features/customer/screens/create_order/controllers/address_picker_controller.dart lib/features/customer/screens/create_order/widgets/address_picker/address_detail_form.dart lib/features/customer/screens/create_order/utils/address_search_result.dart lib/features/driver/screens/widgets/driver_gps_debug_components.dart lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart test/reverse_geocode_result_test.dart test/driver_gps_debug_components_test.dart`

Expected: no issues.

- [ ] **Step 7: Commit phần hiển thị địa chỉ**

```bash
git add apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_components.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart apps/delivery_app/test/driver_gps_debug_components_test.dart
git commit -m "feat: show addresses in driver location check"
```

