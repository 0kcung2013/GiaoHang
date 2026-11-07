import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../location/driver_arrival_fix.dart';
import '../location/driver_foreground_location_service.dart';
import '../location/driver_location_producer_policy.dart';
import 'customer_providers.dart';
import 'driver_position_publisher_provider.dart';
import 'driver_task_priority_provider.dart';
import 'location_providers.dart';

/// GPS của toàn phiên tài xế, tiếp tục khi mở map hoặc đổi đơn ưu tiên.
final driverActiveGpsProvider = Provider.autoDispose.family<void, String>((
  ref,
  userId,
) {
  final location = ref.watch(locationServiceProvider);
  var disposed = false;
  var sampling = false;
  String? foregroundOrder;
  Future<void> accept(Position position) async {
    if (disposed) return;
    final owner = ref.read(driverLocationOwnerProvider(userId));
    if (owner == null) return;
    try {
      await ref
          .read(driverPositionPublisherProvider)
          .publish(
            driverUserId: userId,
            orderId: owner.id,
            fix: DriverArrivalFix(
              position: LatLng(position.latitude, position.longitude),
              capturedAt: position.timestamp,
              accuracy: position.accuracy,
              mode: DriverLocationMode.deviceGps,
            ),
            speedKmh: position.speed.isFinite ? position.speed * 3.6 : null,
          );
    } catch (error) {
      debugPrint('[DriverGPS] publish pending: $error');
    }
  }

  Future<void> sample() async {
    if (sampling || disposed) return;
    sampling = true;
    try {
      final position = await location.getCurrentPosition();
      if (!disposed && position != null) await accept(position);
    } finally {
      sampling = false;
    }
  }

  Future<void> configureForeground() async {
    final order = ref.read(driverLocationOwnerProvider(userId));
    if (order == null || order.id == foregroundOrder) return;
    final driver = await ref.read(driverByUserIdProvider(userId).future);
    if (disposed ||
        driver == null ||
        ref.read(driverLocationOwnerProvider(userId))?.id != order.id) {
      return;
    }
    foregroundOrder = order.id;
    await DriverForegroundLocationService.start(
      driverProfileId: driver.id,
      driverUserId: userId,
      orderId: order.id,
    );
  }

  ref.listen(driverLocationOwnerProvider(userId), (_, _) {
    unawaited(
      configureForeground().catchError((Object e) {
        debugPrint('[DriverGPS] foreground pending: $e');
      }),
    );
  });
  location.startTracking(
    onPosition: (p) => unawaited(accept(p)),
    distanceFilterMeters: 5,
    onError: (e) => debugPrint('[DriverGPS] $e'),
  );
  unawaited(sample());
  unawaited(
    configureForeground().catchError((Object e) {
      debugPrint('[DriverGPS] foreground pending: $e');
    }),
  );
  final timer = Timer.periodic(
    const Duration(seconds: 5),
    (_) => unawaited(sample()),
  );
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    location.stopTracking();
  });
});
