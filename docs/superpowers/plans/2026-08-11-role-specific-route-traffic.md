# Role-Specific Route Traffic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep customer historical-traffic colors stable while realtime GPS advances along a route, and render driver navigation with one blue active polyline.

**Architecture:** Treat customer traffic analysis as an immutable snapshot anchored to one OSRM geometry and evaluation timestamp. GPS updates only clip that snapshot and move the marker; an off-route position triggers a real reroute and a new snapshot. Driver navigation consumes its existing remaining route but renders it directly with `AppColors.routeLine`.

**Tech Stack:** Flutter 3.35.1, Dart `^3.9.0`, flutter_map 7, Riverpod, latlong2, Supabase Realtime GPS.

## Global Constraints

- Do not change Supabase schema, RLS, migrations, Edge Functions, fields, or runtime configuration.
- Customer copy describes UTraffic as historical prediction, never live traffic.
- Driver navigation must not render `DeliveryTrafficRouteLayer`.
- Use `AppColors`, `AppTextStyles`, `AppSpacing`, and `AppRadius` from `giaohang_design`.
- Preserve existing user changes in the dirty worktree.
- Report every touched file that remains over 400 lines.
- Use test-first red-green-refactor for each behavior.

---

### Task 1: Stable customer traffic snapshot

**Files:**
- Create: `apps/delivery_app/lib/features/customer/screens/tracking/utils/tracking_traffic_route.dart`
- Create: `apps/delivery_app/test/tracking_traffic_route_test.dart`

**Interfaces:**
- Consumes: `DeliveryTrafficRouteAnalyzer.analyze`, `DeliveryTrafficSegment`, `LatLng`, `Distance`.
- Produces: `TrackingTrafficRouteSnapshot.build`, `remainingFrom`, and `isOffRoute`.

- [ ] **Step 1: Write the failing snapshot tests**

Create one test that uses a fixed route and fixed `DateTime` to prove `build` captures one stable analysis. Create a second test with manually constructed clear and congested segments, then assert:

```dart
final snapshot = TrackingTrafficRouteSnapshot(
  routePoints: route,
  segments: [clearSegment, congestedSegment],
  evaluatedAt: DateTime(2026, 8, 11, 17, 30),
);
final originalLevels = snapshot.segments.map((s) => s.level).toList();
final remaining = snapshot.remainingFrom(route[2]);
expect(remaining.map((s) => s.level), [DeliveryTrafficLevel.congested]);
expect(remaining.single.points, [route[2], route[3]]);
expect(snapshot.segments.map((s) => s.level), originalLevels);
```

Use a manually constructed snapshot fixture for the exact clipping assertion so the test proves that clipping never reclassifies levels. Add `isOffRoute` assertions for a point on the route and a point over 150 m away.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/tracking_traffic_route_test.dart`

Expected: FAIL because `TrackingTrafficRouteSnapshot` does not exist.

- [ ] **Step 3: Implement the immutable snapshot**

Implement:

```dart
class TrackingTrafficRouteSnapshot {
  TrackingTrafficRouteSnapshot({
    required List<LatLng> routePoints,
    required List<DeliveryTrafficSegment> segments,
    required this.evaluatedAt,
  }) : routePoints = List.unmodifiable(routePoints),
       segments = List.unmodifiable(segments);

  factory TrackingTrafficRouteSnapshot.build({
    required List<LatLng> routePoints,
    required DateTime evaluatedAt,
  });

  final List<LatLng> routePoints;
  final List<DeliveryTrafficSegment> segments;
  final DateTime evaluatedAt;

  List<DeliveryTrafficSegment> remainingFrom(LatLng? current);
  bool isOffRoute(LatLng current, {double thresholdMeters = 150});
}
```

`remainingFrom` finds the closest stored segment point, clips only points before that index, and copies the original `level` and `maxHistoricalMultiplier`. It never invokes the analyzer. `isOffRoute` compares the GPS point with the closest point in `routePoints`.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `flutter test test/tracking_traffic_route_test.dart`

Expected: PASS.

### Task 2: Blue-only driver navigation route

**Files:**
- Modify: `apps/delivery_app/lib/features/driver/screens/navigation/widgets/driver_navigation_map.dart`
- Create: `apps/delivery_app/test/driver_navigation_route_style_test.dart`

**Interfaces:**
- Consumes: `DeliveryMapUtils.remainingRoute` and `AppColors.routeLine`.
- Produces: `DriverNavigationMap.activeRoutePolyline`, a pure static builder used by the widget and test.

- [ ] **Step 1: Write the failing route-style test**

Assert the pure route builder returns exactly one polyline whose points equal the remaining route, color equals `AppColors.routeLine`, and stroke width is `7`. The test must also assert the driver map source no longer depends on traffic analysis through widget behavior, not source-text matching.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/driver_navigation_route_style_test.dart`

Expected: FAIL because `activeRoutePolyline` does not exist and the widget still renders traffic segments.

- [ ] **Step 3: Implement the blue route**

Remove `DeliveryTrafficRouteAnalyzer`, `DeliveryTrafficSegment`, and `DeliveryTrafficRouteLayer` from the driver map. Retain `_remainingRoute` and render:

```dart
if (_remainingRoute != null && _remainingRoute!.length >= 2)
  PolylineLayer(
    polylines: [DriverNavigationMap.activeRoutePolyline(_remainingRoute!)],
  )
```

The static builder returns `Polyline(points: points, color: AppColors.routeLine, strokeWidth: 7)`.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `flutter test test/driver_navigation_route_style_test.dart`

Expected: PASS.

### Task 3: Customer tracking integration and focused file split

**Files:**
- Modify: `apps/delivery_app/lib/features/customer/screens/tracking/tracking_screen.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/tracking/widgets/tracking_map.dart`
- Create: `apps/delivery_app/lib/features/customer/screens/tracking/widgets/tracking_map_canvas.dart`
- Modify: `apps/delivery_app/test/tracking_traffic_route_test.dart`

**Interfaces:**
- Consumes: `TrackingTrafficRouteSnapshot`, current realtime GPS provider, current OSRM service, and current markers.
- Produces: `TrackingRouteRefreshPolicy.shouldReload` and `TrackingMapCanvas`, a stateless renderer that receives already-computed route segments.

- [ ] **Step 1: Extend the failing integration seam test**

Add a pure test for the wished-for API:

```dart
expect(
  TrackingRouteRefreshPolicy.shouldReload(snapshot: snapshot, current: onRoute),
  isFalse,
);
expect(
  TrackingRouteRefreshPolicy.shouldReload(snapshot: snapshot, current: offRoute),
  isTrue,
);
expect(
  TrackingRouteRefreshPolicy.shouldReload(snapshot: null, current: onRoute),
  isTrue,
);
```

- [ ] **Step 2: Run focused tests and verify RED**

Run: `flutter test test/tracking_traffic_route_test.dart`

Expected: FAIL because `TrackingRouteRefreshPolicy` does not exist.

- [ ] **Step 3: Integrate snapshot state**

In `_TrackingMapState`, replace render-time analysis with:

```dart
TrackingTrafficRouteSnapshot? _trafficSnapshot;

void _acceptRoute(List<LatLng> route) {
  _fullRoute = route;
  _trafficSnapshot = TrackingTrafficRouteSnapshot.build(
    routePoints: route,
    evaluatedAt: DateTime.now(),
  );
}
```

On GPS updates, reload OSRM only when `_trafficSnapshot == null` or `_trafficSnapshot!.isOffRoute(pos)`. Otherwise only animate the marker. Build visible traffic with `_trafficSnapshot?.remainingFrom(driverPos) ?? const []`. Clear the snapshot when phase/destination changes; preserve it when a reroute request fails.

Implement `TrackingRouteRefreshPolicy.shouldReload` as the single decision point and call it from both polling and realtime GPS paths.

- [ ] **Step 4: Extract the stateless map canvas**

Create `TrackingMapCanvas` with typed inputs for the controller, center, full route, remaining traffic segments, marker points, fullscreen state, phase legend, and map actions. Move `FlutterMap`, route layers, marker layer, legend, and action overlays from `tracking_map.dart` without changing their visual tokens or semantics.

- [ ] **Step 5: Run targeted map and lifecycle tests**

Run:

```text
flutter test test/tracking_traffic_route_test.dart
flutter test test/delivery_traffic_route_analyzer_test.dart
flutter test test/customer_tracking_completed_map_test.dart
flutter test test/driver_navigation_provider_lifecycle_test.dart
```

Expected: PASS.

### Task 4: Verification and cleanup

**Files:**
- Verify all modified Dart files and tests.

**Interfaces:**
- Consumes: all tasks above.
- Produces: formatted, analyzed, regression-tested implementation.

- [ ] **Step 1: Format changed Dart files**

Run `dart format` on the exact changed Dart files only.

- [ ] **Step 2: Run delivery app analysis**

Run: `flutter analyze`

Expected: no new errors or warnings.

- [ ] **Step 3: Run the delivery app test suite**

Run: `flutter test`

Expected: PASS.

- [ ] **Step 4: Inspect scoped diff and line counts**

Run `git diff --check`, review only task files, and report every touched file over 400 lines. Confirm no database/Supabase file changed.
