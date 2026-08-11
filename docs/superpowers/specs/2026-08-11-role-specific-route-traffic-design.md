# Role-Specific Route Traffic Design

## Goal

Keep historical traffic colors visible only on the customer tracking map, keep the driver navigation route blue, and prevent customer traffic colors from changing merely because a realtime GPS point moved along the same route.

## Product Language

- The current model uses historical UTraffic data. Customer-facing copy must say `Dự báo giao thông theo dữ liệu lịch sử`.
- Do not call the data `realtime traffic`, `giao thông trực tiếp`, or claim that a colored segment is currently congested.
- Realtime refers only to the driver's GPS position delivered through Supabase.

## Role-Specific Presentation

### Customer tracking

- Show the driver's marker moving from realtime GPS updates.
- Show the remaining route in traffic-state colors:
  - green: clear;
  - yellow: moderate;
  - orange: slow;
  - red: historically congestion-prone;
  - blue: outside the historical dataset coverage.
- Keep the existing compact legend, with text and semantic labels so color is not the only signal.
- Render the completed route as a muted contextual line.
- Preserve the traffic classification assigned to each geographic route segment while the driver progresses along that same route.

### Driver navigation

- Draw the active navigation route with a single, high-contrast `AppColors.routeLine` blue polyline.
- Continue trimming the completed portion as the driver moves.
- Do not render `DeliveryTrafficRouteLayer` or a traffic legend on the driver navigation map.
- Keep pickup, drop-off, driver markers, turn instruction, remaining distance, and ETA unchanged.

## Stability Model

Traffic analysis is a route snapshot, not a render-time calculation.

1. When a customer tracking route is first loaded, analyze the full OSRM geometry once using one captured evaluation timestamp.
2. Store the resulting colored segments in widget state, anchored to the full route geometry.
3. On each realtime GPS update, update the driver marker and clip the stored segments to the remaining route. Do not call the traffic model again.
4. Recompute the snapshot only when the route meaningfully changes:
   - tracking phase or destination changes;
   - the driver leaves the current route far enough to require an actual reroute;
   - a new OSRM route replaces the previous route after that reroute.
5. Routine forward progress along the existing geometry must never rescore or recolor the remaining geographic segments.

This separates two independent state changes:

```text
GPS update -> marker position + route progress
Actual reroute -> OSRM geometry + new traffic snapshot
```

## Root-Cause Hypotheses to Verify

The current implementation rebuilds the customer traffic analysis from `remainingRoute` and `DateTime.now()` during `build`. A moving GPS point changes the start of `remainingRoute`, which changes 250 m chunk boundaries and their midpoint coordinates. The historical model can therefore assign different levels to geographically overlapping route pieces.

Secondary contributors to verify are repeated OSRM route replacement after movement and render-time changes to the model timestamp. The implementation must be based on a regression test that reproduces the observed color instability before any production fix is written.

## File Split Plan

`tracking_map.dart` is currently over 500 lines, so the traffic behavior must not add more responsibilities to it.

- Extract pure traffic snapshot/progress logic into `features/customer/screens/tracking/utils/tracking_traffic_route.dart`.
- Extract the map canvas and route/marker overlay rendering into `features/customer/screens/tracking/widgets/tracking_map_canvas.dart` so the touched screen-side file remains focused on state coordination.
- Keep realtime provider wiring, lifecycle, and top-level map state coordination in `tracking_map.dart`.
- Keep driver-only rendering changes local to `driver_navigation_map.dart`.

No database schema, RLS policy, migration, Edge Function, or runtime Supabase configuration changes are in scope.

## Error and Fallback Behavior

- If OSRM fails and only waypoint fallback geometry is available, build one stable traffic snapshot from that fallback geometry.
- If historical traffic coverage is unavailable, use the blue OSRM route and show the existing unavailable-data explanation.
- If realtime GPS pauses, preserve the last driver marker, route progress, and traffic snapshot; polling may continue as the existing fallback.
- A failed reroute must not discard the last valid route or traffic snapshot.

## Test Strategy

1. A pure regression test fixes the timestamp and full route, advances the driver along that route, and asserts that overlapping remaining segments keep their original traffic levels.
2. A widget or layer-level test asserts that driver navigation produces only the blue route and does not include traffic-colored layers.
3. Existing traffic analyzer tests continue to verify thresholds, historical coverage, colors, and legend semantics.
4. Existing realtime tracking and driver navigation lifecycle tests must remain green.

## Acceptance Criteria

- Customer tracking continues to show traffic colors and the historical-data legend.
- Driver navigation shows one blue active polyline and no traffic-color layer.
- Consecutive GPS updates along the same OSRM geometry shorten route progress without recoloring the remaining geographic segments.
- A true reroute may replace both geometry and its traffic snapshot once.
- No Supabase or database changes are made.
- All touched files over 400 lines are reported after implementation.
