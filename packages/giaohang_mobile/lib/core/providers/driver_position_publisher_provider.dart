import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../location/driver_arrival_fix.dart';
import '../location/driver_location_producer_policy.dart';
import '../location/driver_workload_policy.dart';
import 'customer_providers.dart';
import 'driver_task_priority_provider.dart';
import 'location_providers.dart';

final driverPositionPublisherProvider = Provider(DriverPositionPublisher.new);

/// Một vị trí vật lý cho tài xế; tuyến đường không được sửa mẫu này.
class DriverPositionPublisher {
  DriverPositionPublisher(this.ref);
  final Ref ref;
  Future<void> _pending = Future<void>.value();

  void seedLastKnown(LatLng position) {
    if (ref.read(driverPhysicalPositionProvider) == null &&
        position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude.abs() <= 90 &&
        position.longitude.abs() <= 180) {
      ref.read(driverPhysicalPositionProvider.notifier).state = position;
    }
  }

  Future<bool> publish({
    required DriverArrivalFix fix,
    required String driverUserId,
    String? driverProfileId,
    String? orderId,
    double? speedKmh,
    bool force = false,
  }) async {
    final mode = ref.read(driverLocationModeProvider);
    if (!fix.canRestore(
      now: DateTime.now(),
      currentMode: mode,
      currentTrafficDemoKey: fix.trafficDemoKey,
    )) {
      return false;
    }
    final previous = ref.read(driverArrivalFixProvider);
    if (previous != null &&
        previous.mode == mode &&
        fix.capturedAt.isBefore(previous.capturedAt)) {
      return false;
    }
    final owner = ref.read(driverLocationOwnerProvider(driverUserId));
    if (fix.simulated && owner != null && orderId != owner.id) return false;

    ref.read(driverArrivalFixProvider.notifier).state = fix;
    ref.read(driverPhysicalPositionProvider.notifier).state = fix.position;
    final primaryId = orderId ?? owner?.id;
    if (primaryId == null) return true;
    final orders =
        ref.read(driverOrdersProvider(driverUserId)).valueOrNull ?? [];
    final recipients = <String>{
      primaryId,
      for (final o in orders)
        if (o.driverId == driverUserId &&
            (DriverWorkloadPolicy.isWorking(o) || o.isRecipientHeld))
          o.id,
    };
    final send = _pending.then((_) async {
      if (ref
              .read(driverArrivalFixProvider)
              ?.capturedAt
              .isAfter(fix.capturedAt) ??
          false) {
        return;
      }
      await ref
          .read(locationIngestServiceProvider)
          .ingest(
            driverProfileId: driverProfileId,
            driverUserId: driverUserId,
            orderId: primaryId,
            lat: fix.position.latitude,
            lng: fix.position.longitude,
            accuracy: fix.accuracy,
            capturedAt: fix.capturedAt,
            speed: speedKmh == null ? null : speedKmh / 3.6,
            prioritySync: true,
            force: force,
            coordinateSpace: LocationIngestCoordinateSpace.mapCoordinates,
          );
      if (ref
              .read(driverArrivalFixProvider)
              ?.capturedAt
              .isAfter(fix.capturedAt) ??
          false) {
        return;
      }
      final realtime = ref.read(realtimeServiceProvider);
      await Future.wait([
        for (final id in recipients)
          realtime.broadcastDriverLocation(
            orderId: id,
            lat: fix.position.latitude,
            lng: fix.position.longitude,
            speedKmh: speedKmh,
            sampledAt: fix.capturedAt,
          ),
      ]);
    });
    _pending = send.catchError((Object _) {});
    await send;
    return true;
  }
}
