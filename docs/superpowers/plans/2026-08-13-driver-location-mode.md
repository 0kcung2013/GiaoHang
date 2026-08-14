# Driver Location Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cho tài xế chuyển trong phiên app giữa GPS thiết bị thật và tọa độ demo TP.HCM cố định theo email, để chạy tuyến gần vị trí hiện tại hoặc tuyến demo có sẵn.

**Architecture:** Thêm một `DriverLocationMode` thuần và Riverpod provider cấp phiên làm nguồn quyết định duy nhất cho mọi raw-GPS producer. Dashboard, background ingest và navigation cùng dùng policy này; sheet `Kiểm tra vị trí` chỉ đổi mode, publish ngay tọa độ đã chọn và hiển thị phản hồi. Phần resolve tọa độ của navigation được tách khỏi `driver_navigation_screen.dart` (783 dòng) sang model/helper riêng trước khi màn hình được sửa.

**Tech Stack:** Flutter 3.35.1, Dart 3.9.0, Riverpod, flutter_test, latlong2, Supabase location ingest hiện có.

## Global Constraints

- Không thay đổi Supabase schema, RLS, migrations, Edge Functions hoặc database fields.
- Không thay đổi ba tọa độ TP.HCM trong `GeoUtils.testDriverDemoPositions`.
- Không thêm dependency và không đổi runtime config Supabase.
- UI mới phải dùng `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius`; mobile-first ở 375 dp và không dùng Material default chưa style.
- Chỉ giữ một CTA primary; nút GPS thiết bị là secondary, nút demo TP.HCM là primary.
- File Dart mới dùng `snake_case.dart`; ưu tiên dưới 300–400 dòng.
- `driver_navigation_screen.dart` đang 783 dòng: không thêm logic mode trực tiếp; tách resolver sang file model/helper và chỉ thay lời gọi tại màn hình.
- Chỉ chạy test/analyze tập trung cho các file và feature vừa sửa; không chạy full suite, build app hoặc E2E.
- Không đưa các thay đổi risk-report và operations-web đang có trong worktree vào commit của feature này.

---

## File Structure

- Modify `apps/delivery_app/lib/core/location/driver_location_producer_policy.dart`: khai báo mode và quy tắc raw GPS → tọa độ publish/coordinate space.
- Modify `apps/delivery_app/lib/core/providers/location_providers.dart`: cung cấp mode cấp phiên và áp mode cho background GPS.
- Modify `apps/delivery_app/lib/features/driver/screens/home/widgets/availability_toggle_card.dart`: publish lần bật online theo mode hiện tại.
- Modify `apps/delivery_app/lib/features/driver/screens/home/utils/driver_dashboard_location.dart`: tính khoảng cách đơn theo mode hiện tại.
- Modify `apps/delivery_app/lib/features/driver/screens/home/widgets/driver_data_body.dart`: truyền mode vào dashboard resolver.
- Create `apps/delivery_app/lib/features/driver/screens/navigation/models/driver_position_source.dart`: tách source/coordinate resolution khỏi màn navigation lớn.
- Modify `apps/delivery_app/lib/features/driver/screens/navigation/models/driver_arrival_policy.dart`: dùng và re-export `DriverPositionSource` để giữ tương thích import hiện tại.
- Modify `apps/delivery_app/lib/features/driver/screens/navigation/driver_navigation_screen.dart`: gọi resolver đã tách, không giữ logic offset inline.
- Create `apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_location_actions.dart`: hai nút responsive và trạng thái loading/disabled.
- Modify `apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart`: điều phối chọn mode và publish vị trí.
- Modify `apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_components.dart`: banner phản ánh mode đang chọn.
- Create `apps/delivery_app/test/driver_location_mode_test.dart`: unit test policy/provider.
- Modify `apps/delivery_app/test/driver_dashboard_location_test.dart`: regression test khoảng cách theo GPS thật.
- Create `apps/delivery_app/test/driver_navigation_position_source_test.dart`: regression test navigation resolution.
- Create `apps/delivery_app/test/driver_gps_location_actions_test.dart`: widget test hai hành động mới.

---

### Task 1: Session location mode and raw-GPS producers

**Files:**
- Modify: `apps/delivery_app/lib/core/location/driver_location_producer_policy.dart`
- Modify: `apps/delivery_app/lib/core/providers/location_providers.dart:16-83`
- Modify: `apps/delivery_app/lib/features/driver/screens/home/widgets/availability_toggle_card.dart:24-69`
- Create: `apps/delivery_app/test/driver_location_mode_test.dart`

**Interfaces:**
- Consumes: `GeoUtils.applyTestDriverOffset({email, lat, lng})` and `LocationIngestService.ingest(... coordinateSpace:)`.
- Produces: `enum DriverLocationMode { demoHcm, deviceGps }`.
- Produces: `DriverLocationMode.rawGpsCoordinateSpace` returning `LocationIngestCoordinateSpace`.
- Produces: `DriverLocationMode.resolveRawGps({String? email, required double lat, required double lng})` returning `LatLng`.
- Produces: `driverLocationModeProvider` as `StateProvider<DriverLocationMode>` defaulting to `demoHcm`.

- [ ] **Step 1: Write the failing policy/provider tests**

Create `test/driver_location_mode_test.dart` with these assertions:

```dart
import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/providers/location_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('DriverLocationMode', () {
    test('defaults the app session to the existing TP.HCM demo mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(driverLocationModeProvider), DriverLocationMode.demoHcm);
    });

    test('demo mode maps raw GPS to the fixed point for the driver email', () {
      final resolved = DriverLocationMode.demoHcm.resolveRawGps(
        email: 'taixe@gmail.com',
        lat: 21.0285,
        lng: 105.8542,
      );

      expect(resolved, const LatLng(10.7790, 106.6765));
      expect(
        DriverLocationMode.demoHcm.rawGpsCoordinateSpace,
        LocationIngestCoordinateSpace.rawGps,
      );
    });

    test('device mode keeps raw GPS and bypasses the demo mapping', () {
      final resolved = DriverLocationMode.deviceGps.resolveRawGps(
        email: 'taixe@gmail.com',
        lat: 21.0285,
        lng: 105.8542,
      );

      expect(resolved, const LatLng(21.0285, 105.8542));
      expect(
        DriverLocationMode.deviceGps.rawGpsCoordinateSpace,
        LocationIngestCoordinateSpace.mapCoordinates,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run from `apps/delivery_app`:

```bash
flutter test test/driver_location_mode_test.dart
```

Expected: FAIL because `DriverLocationMode`, its extension and `driverLocationModeProvider` do not exist.

- [ ] **Step 3: Implement the minimal mode policy**

In `driver_location_producer_policy.dart`, keep the existing coordinate-space API and add:

```dart
import 'package:latlong2/latlong.dart';

import '../utils/geo_utils.dart';

enum DriverLocationMode { demoHcm, deviceGps }

extension DriverLocationModeRules on DriverLocationMode {
  LocationIngestCoordinateSpace get rawGpsCoordinateSpace => switch (this) {
    DriverLocationMode.demoHcm => LocationIngestCoordinateSpace.rawGps,
    DriverLocationMode.deviceGps =>
      LocationIngestCoordinateSpace.mapCoordinates,
  };

  LatLng resolveRawGps({
    required String? email,
    required double lat,
    required double lng,
  }) => switch (this) {
    DriverLocationMode.demoHcm => GeoUtils.applyTestDriverOffset(
      email: email,
      lat: lat,
      lng: lng,
    ),
    DriverLocationMode.deviceGps => LatLng(lat, lng),
  };
}
```

In `location_providers.dart`, add the provider and make the family stream watch it:

```dart
final driverLocationModeProvider = StateProvider<DriverLocationMode>(
  (ref) => DriverLocationMode.demoHcm,
);
```

Inside `driverLocationStreamProvider`, read `final locationMode = ref.watch(driverLocationModeProvider);` and pass the mode in both calls to `ingest`:

```dart
coordinateSpace: locationMode.rawGpsCoordinateSpace,
```

In `AvailabilityToggleCard._toggle`, read the session mode before ingest and pass the same `coordinateSpace`:

```dart
import '../../../../../core/location/driver_location_producer_policy.dart';

final locationMode = ref.read(driverLocationModeProvider);
await ref.read(locationIngestServiceProvider).ingest(
  driverProfileId: widget.driver.id,
  lat: position.latitude,
  lng: position.longitude,
  heading: position.heading,
  speed: position.speed,
  force: true,
  coordinateSpace: locationMode.rawGpsCoordinateSpace,
);
```

- [ ] **Step 4: Run the policy test and existing producer-policy test**

```bash
flutter test test/driver_location_mode_test.dart test/driver_location_producer_policy_test.dart
```

Expected: PASS with zero failures.

- [ ] **Step 5: Commit only Task 1 files**

```bash
git add apps/delivery_app/lib/core/location/driver_location_producer_policy.dart apps/delivery_app/lib/core/providers/location_providers.dart apps/delivery_app/lib/features/driver/screens/home/widgets/availability_toggle_card.dart apps/delivery_app/test/driver_location_mode_test.dart
git commit -m "feat: add driver location session mode"
```

### Task 2: Dashboard and navigation consume the selected mode

**Files:**
- Modify: `apps/delivery_app/lib/features/driver/screens/home/utils/driver_dashboard_location.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/home/widgets/driver_data_body.dart:81-89`
- Modify: `apps/delivery_app/test/driver_dashboard_location_test.dart`
- Create: `apps/delivery_app/lib/features/driver/screens/navigation/models/driver_position_source.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/navigation/models/driver_arrival_policy.dart:1-28`
- Modify: `apps/delivery_app/lib/features/driver/screens/navigation/driver_navigation_screen.dart:480-489`
- Create: `apps/delivery_app/test/driver_navigation_position_source_test.dart`

**Interfaces:**
- Consumes: `DriverLocationMode.resolveRawGps(...)` and `driverLocationModeProvider` from Task 1.
- Produces: `resolveDriverDashboardPosition({required DriverLocationMode locationMode, required String? email, ...})`.
- Produces: `DriverPositionSource.resolveForPublishing({required DriverLocationMode locationMode, required String? email, required LatLng position})`.
- Preserves: `DriverPositionSource.ingestCoordinateSpace` and the public import through `driver_arrival_policy.dart`.

- [ ] **Step 1: Extend the dashboard test for GPS-device mode**

Import the mode policy and pass `locationMode: DriverLocationMode.demoHcm` to existing resolver calls. Add:

```dart
test('uses raw device GPS when the session selects the current position', () {
  final position = resolveDriverDashboardPosition(
    locationMode: DriverLocationMode.deviceGps,
    email: 'taixe@gmail.com',
    rawLat: 21.0285,
    rawLng: 105.8542,
    storedLat: 10.7790,
    storedLng: 106.6765,
  );

  expect(position, const LatLng(21.0285, 105.8542));
});
```

- [ ] **Step 2: Add the failing navigation source tests**

Create `test/driver_navigation_position_source_test.dart`:

```dart
import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_position_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const raw = LatLng(21.0285, 105.8542);

  test('device GPS uses the fixed TP.HCM point in demo mode', () {
    expect(
      DriverPositionSource.deviceGps.resolveForPublishing(
        locationMode: DriverLocationMode.demoHcm,
        email: 'taixe@gmail.com',
        position: raw,
      ),
      const LatLng(10.7790, 106.6765),
    );
  });

  test('device GPS stays real when current-position mode is selected', () {
    expect(
      DriverPositionSource.deviceGps.resolveForPublishing(
        locationMode: DriverLocationMode.deviceGps,
        email: 'taixe@gmail.com',
        position: raw,
      ),
      raw,
    );
  });

  test('simulation coordinates are never offset again', () {
    expect(
      DriverPositionSource.simulation.resolveForPublishing(
        locationMode: DriverLocationMode.demoHcm,
        email: 'taixe@gmail.com',
        position: raw,
      ),
      raw,
    );
  });
}
```

- [ ] **Step 3: Run both tests and verify RED**

```bash
flutter test test/driver_dashboard_location_test.dart test/driver_navigation_position_source_test.dart
```

Expected: FAIL because the dashboard resolver lacks `locationMode` and `driver_position_source.dart` does not exist.

- [ ] **Step 4: Implement dashboard resolution through the mode policy**

Change the resolver signature and raw-GPS branch:

```dart
LatLng? resolveDriverDashboardPosition({
  required DriverLocationMode locationMode,
  required String? email,
  double? rawLat,
  double? rawLng,
  double? storedLat,
  double? storedLng,
}) {
  if (_isValid(rawLat, rawLng)) {
    return locationMode.resolveRawGps(
      email: email,
      lat: rawLat!,
      lng: rawLng!,
    );
  }
  if (_isValid(storedLat, storedLng)) {
    return LatLng(storedLat!, storedLng!);
  }
  return null;
}
```

In `DriverDashboardBody.build`, watch the provider and pass it:

```dart
final locationMode = ref.watch(driverLocationModeProvider);
final dashboardPosition = resolveDriverDashboardPosition(
  locationMode: locationMode,
  email: email,
  rawLat: currentPosition?.latitude,
  rawLng: currentPosition?.longitude,
  storedLat: driver.currentLat,
  storedLng: driver.currentLng,
);
```

- [ ] **Step 5: Perform the navigation split and minimal screen integration**

Move `DriverPositionSource` and `DriverPositionSourceRules` from `driver_arrival_policy.dart` into the new `driver_position_source.dart`. Keep `ingestCoordinateSpace` and add:

```dart
LatLng resolveForPublishing({
  required DriverLocationMode locationMode,
  required String? email,
  required LatLng position,
}) {
  if (!ingestCoordinateSpace.shouldApplyDemoOffset) return position;
  return locationMode.resolveRawGps(
    email: email,
    lat: position.latitude,
    lng: position.longitude,
  );
}
```

At the top of `driver_arrival_policy.dart`, preserve existing consumers:

```dart
import 'driver_position_source.dart';
export 'driver_position_source.dart';
```

In `_onDriverMoved` of `driver_navigation_screen.dart`, replace the inline `GeoUtils.applyTestDriverOffset` block with:

```dart
var published = source.resolveForPublishing(
  locationMode: ref.read(driverLocationModeProvider),
  email: Supabase.instance.client.auth.currentUser?.email,
  position: newPos,
);
```

Remove the now-unused `geo_utils.dart` import only if `rg` confirms no other use in that file.

- [ ] **Step 6: Run focused dashboard/navigation tests**

```bash
flutter test test/driver_dashboard_location_test.dart test/driver_navigation_position_source_test.dart test/driver_navigation_arrival_regression_test.dart test/driver_navigation_resume_policy_test.dart
```

Expected: PASS with zero failures.

- [ ] **Step 7: Commit only Task 2 files**

```bash
git add apps/delivery_app/lib/features/driver/screens/home/utils/driver_dashboard_location.dart apps/delivery_app/lib/features/driver/screens/home/widgets/driver_data_body.dart apps/delivery_app/test/driver_dashboard_location_test.dart apps/delivery_app/lib/features/driver/screens/navigation/models/driver_position_source.dart apps/delivery_app/lib/features/driver/screens/navigation/models/driver_arrival_policy.dart apps/delivery_app/lib/features/driver/screens/navigation/driver_navigation_screen.dart apps/delivery_app/test/driver_navigation_position_source_test.dart
git commit -m "feat: honor driver location mode across routes"
```

### Task 3: Replace GPS debug actions with current/demo selectors

**Files:**
- Create: `apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_location_actions.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart:22-138,202-326`
- Modify: `apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_components.dart:66-137`
- Create: `apps/delivery_app/test/driver_gps_location_actions_test.dart`

**Interfaces:**
- Consumes: `DriverLocationMode`, `driverLocationModeProvider`, `LocationIngestCoordinateSpace.mapCoordinates`, existing location/driver service providers and design tokens.
- Produces: `DriverGpsLocationActions({DriverLocationMode? applyingMode, required bool canUseDemo, required VoidCallback onUseDeviceGps, required VoidCallback onUseDemoHcm})`.
- Produces: `_applyLocationMode(DriverLocationMode mode)` inside the sheet; the method always publishes an already-resolved point in map coordinate space to prevent double offset.

- [ ] **Step 1: Write the failing action-widget test**

Create `test/driver_gps_location_actions_test.dart`:

```dart
import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/features/driver/screens/widgets/driver_gps_location_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows current and TP.HCM demo actions instead of old actions', (
    tester,
  ) async {
    var selected = DriverLocationMode.demoHcm;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGpsLocationActions(
            applyingMode: null,
            canUseDemo: true,
            onUseDeviceGps: () => selected = DriverLocationMode.deviceGps,
            onUseDemoHcm: () => selected = DriverLocationMode.demoHcm,
          ),
        ),
      ),
    );

    expect(find.text('Dùng vị trí hiện tại'), findsOneWidget);
    expect(find.text('Dùng vị trí demo TP.HCM'), findsOneWidget);
    expect(find.text('Đo lại GPS'), findsNothing);
    expect(find.text('Đồng bộ'), findsNothing);

    await tester.tap(find.text('Dùng vị trí hiện tại'));
    expect(selected, DriverLocationMode.deviceGps);
  });

  testWidgets('disables both actions while applying a mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverGpsLocationActions(
            applyingMode: DriverLocationMode.deviceGps,
            canUseDemo: true,
            onUseDeviceGps: () {},
            onUseDemoHcm: () {},
          ),
        ),
      ),
    );

    final buttons = tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(buttons, hasLength(2));
    expect(buttons.every((button) => button.onPressed == null), isTrue);
    expect(find.text('Đang lấy vị trí...'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the widget test and verify RED**

```bash
flutter test test/driver_gps_location_actions_test.dart
```

Expected: FAIL because `driver_gps_location_actions.dart` and its widget do not exist.

- [ ] **Step 3: Implement the responsive action widget**

Create a `Column` with two 52 dp buttons and `AppSpacing.sm` between them. Use `OutlinedButton.icon` with `Icons.my_location_rounded` for GPS device and `FilledButton.icon` with `Icons.location_city_rounded` for TP.HCM demo. Apply `AppRadius.full`, `AppColors.info` to the secondary action, and `AppColors.accent`/`AppColors.textOnAccent` to the primary action. Use these labels exactly:

```dart
final deviceLabel = applyingMode == DriverLocationMode.deviceGps
    ? 'Đang lấy vị trí...'
    : 'Dùng vị trí hiện tại';
final demoLabel = applyingMode == DriverLocationMode.demoHcm
    ? 'Đang áp dụng demo...'
    : 'Dùng vị trí demo TP.HCM';
```

Set both `onPressed` values to `null` whenever `applyingMode != null`; also disable the demo button when `canUseDemo == false`.

- [ ] **Step 4: Replace the sheet synchronization method with mode application**

In `driver_gps_debug_dialog.dart`:

1. Replace `_isSyncing` with `DriverLocationMode? _applyingMode`.
2. Keep `_loadPosition` for initial load/error retry only.
3. Add `_applyLocationMode(DriverLocationMode mode)`. Import the mode policy
   directly, then implement the flow with the existing providers and error
   helper:

```dart
Future<void> _applyLocationMode(DriverLocationMode mode) async {
  final currentUser = Supabase.instance.client.auth.currentUser;
  final profileId = _driverProfileId;
  final loadedGps = _gpsPosition;
  if (currentUser == null || profileId == null || loadedGps == null) return;

  setState(() {
    _applyingMode = mode;
    _error = null;
    _successMessage = null;
  });

  try {
    LatLng rawGps = loadedGps;
    if (mode == DriverLocationMode.deviceGps) {
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
      if (position == null) {
        throw const _GpsDebugException(
          'Không lấy được GPS. Hãy bật dịch vụ vị trí và cấp quyền cho ứng dụng.',
        );
      }
      rawGps = LatLng(position.latitude, position.longitude);
    } else if (!GeoUtils.hasTestDriverOffset(currentUser.email)) {
      throw const _GpsDebugException(
        'Tài khoản này chưa có vị trí demo TP.HCM.',
      );
    }

    final selected = mode.resolveRawGps(
      email: currentUser.email,
      lat: rawGps.latitude,
      lng: rawGps.longitude,
    );
    final demo = DriverLocationMode.demoHcm.resolveRawGps(
      email: currentUser.email,
      lat: rawGps.latitude,
      lng: rawGps.longitude,
    );

    await ref.read(locationIngestServiceProvider).ingest(
      driverProfileId: profileId,
      lat: selected.latitude,
      lng: selected.longitude,
      force: true,
      prioritySync: true,
      coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
    );
    final refreshed = await ref
        .read(driverServiceProvider)
        .getDriverByUserId(currentUser.id);

    if (!mounted) return;
    ref.read(driverLocationModeProvider.notifier).state = mode;
    setState(() {
      _gpsPosition = rawGps;
      _demoPosition = demo;
      _storedPosition = _storedPoint(
        refreshed?.currentLat,
        refreshed?.currentLng,
      );
      _offsetMeters = _distance(rawGps, demo);
      _successMessage = mode == DriverLocationMode.deviceGps
          ? 'Đang dùng vị trí hiện tại để tính tuyến đường gần bạn.'
          : 'Đã chuyển về vị trí demo TP.HCM của tài khoản.';
    });
  } catch (error) {
    if (!mounted) return;
    setState(() => _error = _readableError(error));
  } finally {
    if (mounted) setState(() => _applyingMode = null);
  }
}
```

4. Compute stored matching against the active mode, not always against demo:

```dart
final locationMode = ref.watch(driverLocationModeProvider);
final expected = locationMode == DriverLocationMode.deviceGps ? gps : demo;
final storedDistance = stored == null ? null : _distance(stored, expected);
```

5. Replace `_buildActions()` with:

```dart
DriverGpsLocationActions(
  applyingMode: _applyingMode,
  canUseDemo: GeoUtils.hasTestDriverOffset(_email),
  onUseDeviceGps: () => _applyLocationMode(DriverLocationMode.deviceGps),
  onUseDemoHcm: () => _applyLocationMode(DriverLocationMode.demoHcm),
),
```

6. Replace the old offset-only footer with `Bạn có thể chuyển giữa GPS hiện tại và điểm demo TP.HCM bất cứ lúc nào.`

- [ ] **Step 5: Make the banner reflect the selected mode**

Add `required DriverLocationMode locationMode` to `DriverGpsDemoBanner`. When `locationMode == DriverLocationMode.deviceGps`, show:

```dart
title: 'Đang dùng vị trí hiện tại'
description: 'Tuyến đường và khoảng cách sẽ tính từ GPS thiết bị.'
color: AppColors.info
icon: Icons.my_location_rounded
```

Otherwise keep the existing demo-account/offset wording and accent styling. Pass `ref.watch(driverLocationModeProvider)` from the sheet.

- [ ] **Step 6: Run the action widget and shell regression tests**

```bash
flutter test test/driver_gps_location_actions_test.dart test/driver_shell_screen_test.dart test/geo_utils_test.dart
```

Expected: PASS with zero failures and no layout exception at 375×800.

- [ ] **Step 7: Format and commit only Task 3 files**

```bash
dart format lib/features/driver/screens/widgets/driver_gps_location_actions.dart lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart lib/features/driver/screens/widgets/driver_gps_debug_components.dart test/driver_gps_location_actions_test.dart
git add apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_location_actions.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_components.dart apps/delivery_app/test/driver_gps_location_actions_test.dart
git commit -m "feat: switch driver between current and demo locations"
```

### Task 4: Focused verification and file-size audit

**Files:**
- Verify: all files listed in Tasks 1–3.
- Do not modify: Supabase files, runtime config, risk-report files or operations-web files.

**Interfaces:**
- Consumes: completed feature from Tasks 1–3.
- Produces: fresh test/analyze evidence and an explicit report of files over 400 lines.

- [ ] **Step 1: Format every changed Dart file once**

From repository root:

```bash
dart format apps/delivery_app/lib/core/location/driver_location_producer_policy.dart apps/delivery_app/lib/core/providers/location_providers.dart apps/delivery_app/lib/features/driver/screens/home/widgets/availability_toggle_card.dart apps/delivery_app/lib/features/driver/screens/home/utils/driver_dashboard_location.dart apps/delivery_app/lib/features/driver/screens/home/widgets/driver_data_body.dart apps/delivery_app/lib/features/driver/screens/navigation/models/driver_position_source.dart apps/delivery_app/lib/features/driver/screens/navigation/models/driver_arrival_policy.dart apps/delivery_app/lib/features/driver/screens/navigation/driver_navigation_screen.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_location_actions.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_components.dart apps/delivery_app/test/driver_location_mode_test.dart apps/delivery_app/test/driver_dashboard_location_test.dart apps/delivery_app/test/driver_navigation_position_source_test.dart apps/delivery_app/test/driver_gps_location_actions_test.dart
```

Expected: formatter exits 0 and changes only the listed Dart files.

- [ ] **Step 2: Run the complete focused test set once**

From `apps/delivery_app`:

```bash
flutter test test/driver_location_mode_test.dart test/driver_location_producer_policy_test.dart test/driver_dashboard_location_test.dart test/driver_navigation_position_source_test.dart test/driver_navigation_arrival_regression_test.dart test/driver_navigation_resume_policy_test.dart test/driver_gps_location_actions_test.dart test/driver_shell_screen_test.dart test/geo_utils_test.dart
```

Expected: all listed tests pass with zero failures.

- [ ] **Step 3: Run focused analyze**

From `apps/delivery_app`, run these scopes once each:

```bash
flutter analyze lib/core/location/driver_location_producer_policy.dart
flutter analyze lib/core/providers/location_providers.dart
flutter analyze lib/features/driver
flutter analyze test/driver_location_mode_test.dart
flutter analyze test/driver_dashboard_location_test.dart
flutter analyze test/driver_navigation_position_source_test.dart
flutter analyze test/driver_gps_location_actions_test.dart
```

Expected: each command exits 0 with `No issues found!`.

- [ ] **Step 4: Audit scope, diff and file sizes**

```bash
git status --short
git diff --check
git diff --stat
```

Count the touched production files. Report `driver_navigation_screen.dart` as over 400 lines even after the targeted split; confirm no other touched file newly exceeds 400 lines. Confirm the diff contains no Supabase/backend/config changes and no unrelated worktree files.

- [ ] **Step 5: Commit any verification-only formatting correction**

Only when Step 1 changed one of the feature files after its task commit:

```bash
git add apps/delivery_app/lib/core/location/driver_location_producer_policy.dart apps/delivery_app/lib/core/providers/location_providers.dart apps/delivery_app/lib/features/driver/screens/home/widgets/availability_toggle_card.dart apps/delivery_app/lib/features/driver/screens/home/utils/driver_dashboard_location.dart apps/delivery_app/lib/features/driver/screens/home/widgets/driver_data_body.dart apps/delivery_app/lib/features/driver/screens/navigation/models/driver_position_source.dart apps/delivery_app/lib/features/driver/screens/navigation/models/driver_arrival_policy.dart apps/delivery_app/lib/features/driver/screens/navigation/driver_navigation_screen.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_location_actions.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_dialog.dart apps/delivery_app/lib/features/driver/screens/widgets/driver_gps_debug_components.dart apps/delivery_app/test/driver_location_mode_test.dart apps/delivery_app/test/driver_dashboard_location_test.dart apps/delivery_app/test/driver_navigation_position_source_test.dart apps/delivery_app/test/driver_gps_location_actions_test.dart
git commit -m "style: format driver location mode changes"
```

Do not create this commit when the formatter produced no diff.
